class LlvmMesos < Formula
  desc "Mesos-specific LLVM tools (`clang-format` and `clang-tidy`)"

  head do
    url "http://llvm.org/git/llvm.git", :branch => "release_38"

    resource "clang" do
      url "https://github.com/mesos/clang.git", :branch => "mesos_38"
    end

    resource "clang-tools-extra" do
      url "https://github.com/mesos/clang-tools-extra.git", :branch => "mesos_38"
    end

    resource "libcxx" do
      url "http://llvm.org/git/libcxx.git", :branch => "release_38"
    end
  end

  option :universal

  depends_on "cmake" => :build

  # version suffix
  def ver
    "mesos"
  end

  # LLVM installs its own standard library which confuses stdlib checking.
  cxxstdlib_check :skip

  # Apple's libstdc++ is too old to build LLVM
  fails_with :gcc

  def install
    # Apple's libstdc++ is too old to build LLVM
    ENV.libcxx if ENV.compiler == :clang

    (buildpath/"tools/clang").install resource("clang")
    (buildpath/"tools/clang/tools/extra").install resource("clang-tools-extra")
    (buildpath/"projects/libcxx").install resource("libcxx")

    install_prefix = lib/"llvm-#{ver}"

    args = %w[
      -DLLVM_OPTIMIZED_TABLEGEN=On
      -DLLVM_BUILD_LLVM_DYLIB=On
    ]

    args  << "-DCMAKE_INSTALL_PREFIX=#{install_prefix}"

    if build.universal?
      ENV.permit_arch_flags
      args << "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.universal_archs.as_cmake_arch_flags}"
    end

    mktemp do
      system "cmake", "-G", "Unix Makefiles", buildpath, *(std_cmake_args + args)
      system "cmake --build . --target install"
    end

    Dir.glob(install_prefix/"bin/*") do |exec_path|
      basename = File.basename(exec_path)
      bin.install_symlink exec_path => "#{basename}-#{ver}"
    end

    Dir.glob(install_prefix/"share/clang/*") do |script|
      basename = File.basename(script, ".*")
      extname = File.extname(script)
      case extname
      when ".py"
        if basename.include? "clang-format"
          inreplace script, "binary = 'clang-format'", "binary = 'clang-format-#{ver}'"
        elsif basename.include? "clang-tidy"
          inreplace script, "default='clang-tidy'", "default='clang-tidy-#{ver}'"
        end
      when ".el"
        inreplace script, "executable-find \"clang-format\"", "executable-find \"clang-format-#{ver}\""
      when ".applescript"
        inreplace script, "path/to/clang-format", "path/to/clang-format-#{ver}"
      end
      (share/"clang-#{ver}").install_symlink script => "#{basename}-#{ver}#{extname}"
    end
  end

  test do
    # NB: below C code is messily formatted on purpose.
    (testpath/"test.c").write <<-EOS
      int         main(char *args) { \n   \t printf("hello"); }
    EOS

    assert_equal "int main(char *args) { printf(\"hello\"); }\n",
        shell_output("#{bin}/clang-format -style=Google test.c")
  end
end
