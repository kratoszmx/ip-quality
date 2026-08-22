# frozen_string_literal: true

# Read a local file through one already-open descriptor and reject symlinks,
# hard links, ownership changes, and path replacement races. This module is
# intentionally independent of Clash so it can later move to a repository-wide
# safety library without dragging IP-quality policy with it.
module IpQuality
  module SafeSnapshot
    class Error < StandardError
      attr_reader :reason

      def initialize(reason, path)
        @reason = reason
        super("unsafe local file (#{reason}): #{path}")
      end
    end

    Snapshot = Struct.new(:path, :bytes, :stat)

    module_function

    def read(path, allowed_modes: [0o600, 0o644], max_bytes: 16 * 1024 * 1024)
      capture(path, allowed_modes: allowed_modes, max_bytes: max_bytes)
    end

    def verify(path, allowed_modes:)
      capture(path, allowed_modes: allowed_modes, max_bytes: nil)
    end

    def verify_directory(path)
      expanded = File.expand_path(path)
      stat = File.lstat(expanded)
      raise Error.new(:symlink, expanded) if stat.symlink?
      raise Error.new(:not_directory, expanded) unless stat.directory?
      raise Error.new(:wrong_owner, expanded) unless stat.uid == Process.euid
      raise Error.new(:writable_by_other_users, expanded) unless (stat.mode & 0o022).zero?

      expanded
    rescue Errno::ENOENT
      raise Error.new(:missing_or_replaced, expanded || path)
    rescue Errno::EACCES, Errno::EPERM
      raise Error.new(:unreadable, expanded || path)
    end

    def capture(path, allowed_modes:, max_bytes:)
      expanded = File.expand_path(path)
      before = File.lstat(expanded)
      validate_stat!(before, expanded, allowed_modes)

      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      snapshot = File.open(expanded, flags) do |file|
        opened = file.stat
        validate_stat!(opened, expanded, allowed_modes)
        validate_identity!(before, opened, expanded)

        bytes = nil
        if max_bytes
          bytes = file.read(max_bytes + 1)
          raise Error.new(:too_large, expanded) if bytes.bytesize > max_bytes
          bytes.freeze
        end

        Snapshot.new(expanded, bytes, opened)
      end

      after = File.lstat(expanded)
      validate_stat!(after, expanded, allowed_modes)
      validate_identity!(before, after, expanded)
      snapshot
    rescue Errno::ENOENT
      raise Error.new(:missing_or_replaced, expanded || path)
    rescue Errno::ELOOP
      raise Error.new(:symlink, expanded || path)
    rescue Errno::EACCES, Errno::EPERM
      raise Error.new(:unreadable, expanded || path)
    end
    private_class_method :capture

    def same?(left, right)
      left.bytes == right.bytes &&
        left.stat.dev == right.stat.dev &&
        left.stat.ino == right.stat.ino &&
        left.stat.uid == right.stat.uid
    end

    def validate_stat!(stat, path, allowed_modes)
      raise Error.new(:symlink, path) if stat.symlink?
      raise Error.new(:not_regular, path) unless stat.file?
      raise Error.new(:wrong_owner, path) unless stat.uid == Process.euid
      raise Error.new(:hard_link, path) unless stat.nlink == 1

      mode = stat.mode & 0o777
      raise Error.new(:unsafe_mode, path) unless allowed_modes.include?(mode)
    end
    private_class_method :validate_stat!

    def validate_identity!(before, after, path)
      stable = before.dev == after.dev &&
        before.ino == after.ino &&
        before.uid == after.uid &&
        before.nlink == after.nlink &&
        before.mode == after.mode &&
        before.size == after.size
      raise Error.new(:changed_while_reading, path) unless stable
    end
    private_class_method :validate_identity!
  end
end
