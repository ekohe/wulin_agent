# frozen_string_literal: true

require "spec_helper"
require "sass-embedded"
require "tmpdir"

# Compiles wulin_agent.scss the way a wulin_master v3 host's dart-sass does,
# once per Materialize palette, and checks the colors it compiles in.
RSpec.describe "wulin_agent.scss" do
  root = File.expand_path("..", __dir__)
  node_modules = File.join(root, "spec/dummy/node_modules")
  stylesheet = File.join(root, "app/assets/stylesheets/wulin_agent.scss")
  palette_file = File.join(node_modules, "materialize-css/sass/components/_color-variables.scss")

  it "finds Materialize, which spec/dummy/bin/build-assets installs" do
    expect(File).to exist(palette_file), "#{palette_file} is missing; run spec/dummy/bin/build-assets"
  end

  # Every name config.color_theme can take, with its base shade.
  palette = File.exist?(palette_file) ? File.read(palette_file).scan(/^\$([a-z-]+): \(\s*"base":\s*(#\h{6})/).to_h : {}

  def self.compile(stylesheet, node_modules, theme)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "_theme.generated.scss"), "$color-theme: '#{theme}';\n")
      Sass.compile(stylesheet, load_paths: [dir, node_modules], quiet_deps: true, silence_deprecations: ["import"]).css
    end
  end

  # The custom properties declared on the panel root (and the toggle slot).
  def tokens(css)
    block = css[/#wulin-agent-root,\s*\.wulin-agent-toggle-slot\s*\{([^}]*)\}/m, 1]
    raise "no token block in the compiled CSS" unless block

    block.scan(/(--wulin-agent-[a-z0-9-]+):\s*([^;]+);/).to_h { |name, value| [name, value.strip] }
  end

  def rgb(value)
    case value
    when /\A#(\h)(\h)(\h)\z/
      [$1, $2, $3].map { |c| (c * 2).to_i(16) }
    when /\A#(\h{2})(\h{2})(\h{2})\z/
      [$1, $2, $3].map { |c| c.to_i(16) }
    when /\Argba?\(([^)]*)\)\z/
      $1.split(/[\s,\/]+/).first(3).map { |c| c.end_with?("%") ? c.to_f * 2.55 : c.to_f }
    else
      raise "unparsed color #{value.inspect}"
    end
  end

  def luminance(color)
    r, g, b = rgb(color).map do |channel|
      c = channel / 255.0
      (c <= 0.04045) ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def contrast(a, b)
    la, lb = [luminance(a), luminance(b)].sort.reverse
    (la + 0.05) / (lb + 0.05)
  end

  # A translucent tint (main-soft at 12%, error-soft at 10%) composited on a background.
  def tint(color, over, alpha)
    format("#%02x%02x%02x", *rgb(color).zip(rgb(over)).map { |c, bg| (c * alpha + bg * (1 - alpha)).round })
  end

  it "reads the Materialize palette" do
    expect(palette).to include("blue" => "#2196F3", "yellow" => "#ffeb3b")
    expect(palette.size).to be >= 19
  end

  palette.each do |theme, base|
    context "with config.color_theme #{theme}" do
      let(:css) { self.class.compile(stylesheet, node_modules, theme) }
      let(:token) { tokens(css) }

      it "takes the theme's base shade as the accent" do
        expect(token["--wulin-agent-main"].downcase).to eq(base.downcase)
      end

      it "keeps white text on every filled button at 4.5:1 or more" do
        %w[main-strong main-hover error-strong error-hover disabled].each do |fill|
          ratio = contrast(token["--wulin-agent-on-main"], token["--wulin-agent-#{fill}"])
          expect(ratio).to be >= 4.5, "white on #{fill} (#{token["--wulin-agent-#{fill}"]}) is #{ratio.round(2)}:1"
        end
      end

      # The history column is bg-subtle; its active row and + New hover add the tint.
      it "keeps accent text at 4.5:1 or more on every background it sits on" do
        strong = token["--wulin-agent-main-strong"]
        main = token["--wulin-agent-main"]

        %w[--wulin-agent-bg --wulin-agent-bg-subtle --wulin-agent-row-odd].each do |background|
          ratio = contrast(strong, token[background])
          expect(ratio).to be >= 4.5, "main-strong on #{background} is #{ratio.round(2)}:1"

          ratio = contrast(strong, tint(main, token[background], 0.12))
          expect(ratio).to be >= 4.5, "main-strong on main-soft over #{background} is #{ratio.round(2)}:1"
        end
      end
    end
  end

  it "keeps error text at 4.5:1 or more on the error tint" do
    token = tokens(self.class.compile(stylesheet, node_modules, "blue"))
    strong = token["--wulin-agent-error-strong"]

    expect(contrast(strong, tint(token["--wulin-agent-error"], token["--wulin-agent-bg"], 0.1))).to be >= 4.5
  end

  # The set itself was validated for color-vision deficiency with the dataviz
  # palette validator; these guard what a later edit could quietly break.
  it "keeps the chart series distinct, visible on white and apart from status colors" do
    token = tokens(self.class.compile(stylesheet, node_modules, "blue"))
    series = (1..6).map { |i| token["--wulin-agent-chart-#{i}"].downcase }
    status = %w[success error error-strong error-hover warning warning-strong info].map { |name| token["--wulin-agent-#{name}"].downcase }

    expect(series.uniq.size).to eq(6)
    expect(series & status).to be_empty
    series.each do |color|
      expect(contrast(color, token["--wulin-agent-bg"])).to be >= 3, "chart color #{color} is under 3:1 on white"
    end
  end

  it "resolves every color at compile time" do
    css = self.class.compile(stylesheet, node_modules, "blue")

    expect(css).not_to include("color-mix(")
    expect(css).not_to include("--wulin-secondary-color")
  end
end
