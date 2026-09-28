#!/usr/bin/env ruby

require "yaml"
require "erb"

ROOT = File.expand_path("..", __dir__)

class CvRenderer
  attr_reader :cv, :private_data, :data

  def initialize
    @cv = load_yaml("_data/cv.yml")

    @private_data = load_yaml(
      "cv/private.yml",
      required: false
    )

    @data = {}

    %w[
      publications
      preprints
      teaching
      community
      talks
    ].each do |name|
      @data[name] = load_yaml("_data/#{name}.yml")
    end
  end

  def load_yaml(path, required: true)
    full_path = File.join(ROOT, path)

    unless File.exist?(full_path)
      raise "Missing required file: #{path}" if required
      return {}
    end

    YAML.safe_load(
      File.read(full_path),
      aliases: true
    ) || {}
  end

  # ----------------------------------------------------------
  # LaTeX escaping
  # ----------------------------------------------------------

  def escape_latex(text)
    text.to_s.each_char.map do |char|
      case char
      when "\\"
        "\\textbackslash{}"
      when "&"
        "\\&"
      when "%"
        "\\%"
      when "$"
        "\\$"
      when "#"
        "\\#"
      when "_"
        "\\_"
      when "{"
        "\\{"
      when "}"
        "\\}"
      when "~"
        "\\textasciitilde{}"
      when "^"
        "\\textasciicircum{}"
      when "–"
        "--"
      when "—"
        "---"
      when "·"
        "\\textperiodcentered{}"
      else
        char
      end
    end.join
  end

  # ----------------------------------------------------------
  # Links
  # ----------------------------------------------------------

  def normalize_url(url)
    return url if url.match?(/\Ahttps?:\/\//)
    return url if url.start_with?("mailto:")

    website = cv["website"]

    unless website
      raise "Missing 'website' in _data/cv.yml; it is needed to resolve relative links."
    end

    base = website.sub(%r{/$}, "")
    path = url.sub(%r{\A/}, "")

    "#{base}/#{path}"
  end

  # ----------------------------------------------------------
  # Small Markdown subset used by the website YAML
  # ----------------------------------------------------------

  def tex(text)
    source = text.to_s.dup
    protected = []

    protect = lambda do |latex|
      token = "CVTOKEN#{protected.length}END"
      protected << latex
      token
    end

    # *[italic link](url)*
    source.gsub!(
      /\*\[([^\]]+)\]\(([^)]+)\)\*/
    ) do
      label = escape_latex(Regexp.last_match(1))
      url   = normalize_url(Regexp.last_match(2))

      protect.call(
        "\\textit{\\href{\\detokenize{#{url}}}{#{label}}}"
      )
    end

    # [ordinary link](url)
    source.gsub!(
      /\[([^\]]+)\]\(([^)]+)\)/
    ) do
      label = escape_latex(Regexp.last_match(1))
      url   = normalize_url(Regexp.last_match(2))

      protect.call(
        "\\href{\\detokenize{#{url}}}{#{label}}"
      )
    end

    # *italics*
    source.gsub!(
      /\*([^*]+)\*/
    ) do
      protect.call(
        "\\textit{#{escape_latex(Regexp.last_match(1))}}"
      )
    end

    result = escape_latex(source)

    protected.each_with_index do |latex, index|
      result.gsub!("CVTOKEN#{index}END", latex)
    end

    result
  end

  # ----------------------------------------------------------
  # Dates
  # ----------------------------------------------------------

  def cv_date(entry)
    return entry["date"] if entry["date"]

    start_date = entry["start"]

    unless start_date
      raise "Entry has no date information: #{entry.inspect}"
    end

    return "#{start_date} – present" if entry["ongoing"]
    return "#{start_date} – #{entry["end"]}" if entry["end"]

    start_date
  end

  # ----------------------------------------------------------
  # Timeline data
  # ----------------------------------------------------------

  def timeline_groups(groups)
    Array(groups).filter_map do |group|
      next if group["cv"] == false

      items = Array(group["items"]).reject do |item|
        item["cv"] == false
      end

      next if items.empty?

      group.merge("items" => items)
    end
  end

  def render_item(item)
    Array(item["lines"]).each_with_index.map do |line, index|
      rendered = tex(line)

      if index.zero?
        "{\\color{cvtext} #{rendered}}"
      else
        "\\par{\\small\\color{cvtext} #{rendered}}"
      end
    end.join
  end

  def template_binding
    binding
  end
end

renderer = CvRenderer.new

template = ERB.new(
  File.read(File.join(ROOT, "cv/template.tex.erb")),
  trim_mode: "-"
)

output = template.result(renderer.template_binding)

File.write(
  File.join(ROOT, "cv/cv.tex"),
  output
)

puts "Generated cv/cv.tex"