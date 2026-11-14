require "test_helper"
require "open3"
require "tmpdir"

class WrapCliTest < ActiveSupport::TestCase
  test "configure uses the public app when the default URL is accepted" do
    Dir.mktmpdir do |directory|
      output, error, status = Open3.capture3(
        { "HOME" => directory },
        RbConfig.ruby, Rails.root.join("bin/wrap").to_s, "configure",
        stdin_data: "example-token\n\n"
      )

      assert status.success?, error
      assert_includes output, "https://wrap.rossvz.com"
      config = YAML.load_file(File.join(directory, ".config/wrap/config.yml"))
      assert_equal "https://wrap.rossvz.com", config["base_url"]
    end
  end
end
