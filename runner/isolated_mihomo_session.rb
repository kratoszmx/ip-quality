# frozen_string_literal: true

require "fileutils"
require "open3"
require "socket"
require "tmpdir"
require_relative "../common/network_environment"
require_relative "../common/safe_snapshot"

module IpQuality
  class IsolatedMihomoSession
    class Error < StandardError; end

    DEFAULT_MIHOMO = "/Applications/Clash Verge.app/Contents/MacOS/verge-mihomo".freeze
    LSOF = "/usr/sbin/lsof".freeze
    START_TIMEOUT_SECONDS = 10
    STOP_TIMEOUT_SECONDS = 3
    MAX_PORT_ATTEMPTS = 5
    WORKSPACE_PREFIX = "ip-quality-leaf-".freeze
    OWNER_MARKER = ".ipquality-owner-pid".freeze

    attr_reader :port

    def initialize(profile, leaf_name, mihomo_path: DEFAULT_MIHOMO, temp_parent: nil)
      @profile = profile
      @leaf_name = leaf_name
      @mihomo_path = verify_executable(mihomo_path)
      @temp_parent = temp_parent || preferred_temp_parent
      @pid = nil
      @reaped = false
      @workspace = nil
      @port = nil
      @stale_cleanup_done = false
    end

    def with_running
      start
      yield self
    ensure
      stop
    end

    def configuration_test
      with_workspace do
        reservation = reserve_loopback_port
        begin
          write_config(reservation.addr[1])
          test_config!
        ensure
          reservation.close
        end
      end
      true
    end

    def proxy_environment
      raise Error, "isolated Mihomo is not running" unless @pid && !@reaped && @port

      endpoint = "http://127.0.0.1:#{@port}"
      environment = NetworkEnvironment.without_proxy_variables
      environment.merge!(
        "ALL_PROXY" => endpoint,
        "HTTP_PROXY" => endpoint,
        "HTTPS_PROXY" => endpoint,
        "all_proxy" => endpoint,
        "http_proxy" => endpoint,
        "https_proxy" => endpoint,
        "IPQUALITY_ISOLATED_EGRESS" => "1"
      )
    end

    def stop
      stop_process
    ensure
      begin
        remove_workspace
      ensure
        @port = nil
      end
    end

    private

    def start
      raise Error, "isolated Mihomo session is already running" if @pid

      create_workspace
      MAX_PORT_ATTEMPTS.times do
        reservation = reserve_loopback_port
        candidate_port = reservation.addr[1]
        write_config(candidate_port)
        test_config!
        reservation.close
        reservation = nil

        spawn_mihomo
        if wait_for_owned_listener(candidate_port)
          @port = candidate_port
          return true
        end

        stop_process
      ensure
        reservation.close if reservation && !reservation.closed?
      end
      raise Error, "Mihomo did not establish an owned loopback listener after #{MAX_PORT_ATTEMPTS} attempts"
    rescue StandardError
      stop
      raise
    end

    def with_workspace
      create_workspace
      yield
    ensure
      remove_workspace
    end

    def create_workspace
      return if @workspace

      cleanup_stale_workspaces unless @stale_cleanup_done
      @workspace = Dir.mktmpdir("#{WORKSPACE_PREFIX}#{Process.pid}-", @temp_parent)
      File.chmod(0o700, @workspace)
      write_owner_marker
      @config_path = File.join(@workspace, "isolated.mihomo.yaml")
      @log_path = File.join(@workspace, "mihomo.log")
    rescue SystemCallError => error
      raise Error, "cannot create a private isolated workspace: #{error.class}"
    end

    def remove_workspace
      return unless @workspace

      FileUtils.remove_entry_secure(@workspace) if File.exist?(@workspace)
    ensure
      @workspace = nil
      @config_path = nil
      @log_path = nil
    end

    def cleanup_stale_workspaces
      Dir.glob(File.join(@temp_parent, "#{WORKSPACE_PREFIX}*")).each do |path|
        next unless stale_workspace_owned_by_current_user?(path)

        FileUtils.remove_entry_secure(path)
      end
      @stale_cleanup_done = true
    rescue SystemCallError => error
      raise Error, "cannot remove an abandoned private workspace: #{error.class}"
    end

    def stale_workspace_owned_by_current_user?(path)
      stat = File.lstat(path)
      return false unless stat.directory? && !stat.symlink? && stat.uid == Process.euid
      return false unless (stat.mode & 0o777) == 0o700

      pid = workspace_owner_pid(path)
      pid && pid != Process.pid && !process_alive?(pid)
    rescue Errno::ENOENT, Errno::EACCES, SafeSnapshot::Error
      false
    end

    def workspace_owner_pid(path)
      marker = File.join(path, OWNER_MARKER)
      if File.exist?(marker) || File.symlink?(marker)
        value = SafeSnapshot.read(marker, max_bytes: 32).bytes.strip
        return Integer(value, 10) if value.match?(/\A[1-9][0-9]*\z/)

        return nil
      end

      match = File.basename(path).match(/\A#{Regexp.escape(WORKSPACE_PREFIX)}([1-9][0-9]*)-/)
      match && Integer(match[1], 10)
    rescue ArgumentError
      nil
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def write_owner_marker
      marker = File.join(@workspace, OWNER_MARKER)
      File.open(marker, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write("#{Process.pid}\n")
        file.flush
        file.fsync
      end
      File.chmod(0o600, marker)
    end

    def preferred_temp_parent
      candidate = File.expand_path("~/tmp/work/infrastructure/network")
      stat = File.lstat(candidate)
      if stat.directory? && !stat.symlink? && stat.uid == Process.euid && (stat.mode & 0o077).zero?
        return candidate
      end
      Dir.tmpdir
    rescue Errno::ENOENT, Errno::EACCES
      Dir.tmpdir
    end

    def verify_executable(path)
      snapshot = SafeSnapshot.read(path, allowed_modes: [0o700, 0o750, 0o755], max_bytes: nil)
      mode = snapshot.stat.mode
      raise Error, "Mihomo path is not executable" if (mode & 0o111).zero?

      snapshot.path
    rescue SafeSnapshot::Error => error
      raise Error, error.message
    end

    def reserve_loopback_port
      TCPServer.new("127.0.0.1", 0)
    rescue SystemCallError => error
      raise Error, "cannot reserve an isolated loopback port: #{error.class}"
    end

    def write_config(candidate_port)
      rendered = @profile.render(@leaf_name, mixed_port: candidate_port)
      File.open(@config_path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.write(rendered)
        file.flush
        file.fsync
      end
      File.chmod(0o600, @config_path)
    end

    def mihomo_environment
      NetworkEnvironment.without_proxy_variables.merge(
        "HOME" => @workspace,
        "TMPDIR" => @workspace
      )
    end

    def mihomo_command(test: false)
      command = [@mihomo_path, "-d", @workspace, "-f", @config_path]
      command << "-t" if test
      command
    end

    def test_config!
      _stdout, _stderr, status = Open3.capture3(mihomo_environment, *mihomo_command(test: true))
      return if status.success?

      raise Error, "Mihomo rejected the isolated leaf configuration (exit #{status.exitstatus || "signal"})"
    end

    def spawn_mihomo
      log = File.open(@log_path, File::WRONLY | File::CREAT | File::TRUNC, 0o600)
      @pid = Process.spawn(
        mihomo_environment,
        *mihomo_command,
        in: File::NULL,
        out: log,
        err: log,
        pgroup: true,
        close_others: true
      )
      @reaped = false
    ensure
      log.close if log
    end

    def wait_for_owned_listener(candidate_port)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + START_TIMEOUT_SECONDS
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        return false if reap_if_exited
        return true if listener_owned_by_child?(candidate_port)

        sleep 0.1
      end
      false
    end

    def listener_owned_by_child?(candidate_port)
      output, status = Open3.capture2e(
        LSOF,
        "-nP",
        "-a",
        "-p",
        @pid.to_s,
        "-iTCP:#{candidate_port}",
        "-sTCP:LISTEN",
        "-Fn"
      )
      return false unless status.success?

      expected = "n127.0.0.1:#{candidate_port}"
      output.lines.map(&:strip).include?(expected)
    rescue SystemCallError
      raise Error, "cannot verify loopback listener ownership with #{LSOF}"
    end

    def reap_if_exited
      return true if @reaped

      waited = Process.waitpid2(@pid, Process::WNOHANG)
      return false unless waited

      @reaped = true
      @pid = nil
      true
    rescue Errno::ECHILD
      @reaped = true
      @pid = nil
      true
    end

    def stop_process
      return unless @pid

      if reap_if_exited
        @pid = nil
        return
      end

      process_group_signal("TERM")
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + STOP_TIMEOUT_SECONDS
      until Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        break if reap_if_exited

        sleep 0.05
      end
      unless @reaped
        process_group_signal("KILL")
        Process.waitpid(@pid)
        @reaped = true
      end
    rescue Errno::ECHILD
      @reaped = true
    ensure
      @pid = nil
    end

    def process_group_signal(signal)
      Process.kill(signal, -@pid)
    rescue Errno::ESRCH
      nil
    end
  end
end
