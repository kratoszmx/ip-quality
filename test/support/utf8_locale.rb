# frozen_string_literal: true

# Fixtures and zsh probes compare UTF-8 text and display widths. Pin the locale
# so a C/POSIX caller shell cannot turn byte counts into width failures.
ENV["LC_ALL"] = "en_US.UTF-8"
Encoding.default_external = Encoding::UTF_8
