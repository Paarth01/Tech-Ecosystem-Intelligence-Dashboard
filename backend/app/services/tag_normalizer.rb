# Turns the many spellings of a technology ("reactjs", "React.js", "react") into
# one canonical tag, and finds technology names mentioned inside free text.
module TagNormalizer
  ALIASES = {
    "js" => "javascript", "ecmascript" => "javascript", "ts" => "typescript",
    "nextjs" => "next.js", "reactjs" => "react", "react.js" => "react",
    "vuejs" => "vue", "vue.js" => "vue", "nuxt" => "nuxtjs", "nuxt.js" => "nuxtjs",
    "py" => "python", "golang" => "go", "k8s" => "kubernetes",
    "ai" => "artificial intelligence", "ml" => "machine learning",
    "llm" => "large language models", "llms" => "large language models",
    "nlp" => "natural language processing",
    "pg" => "postgresql", "postgres" => "postgresql",
    "css3" => "css", "html5" => "html", "tailwind" => "tailwindcss",
    "node" => "nodejs", "node.js" => "nodejs",
    "csharp" => "c#", "cpp" => "c++", "huggingface" => "hugging face",
    "solid" => "solidjs", "solid.js" => "solidjs", "rustlang" => "rust",
    "wasm" => "webassembly", "expressjs" => "express",
    "github-actions" => "github actions", "ci-cd" => "ci/cd"
  }.freeze

  # Names we look for inside titles and descriptions.
  TECH_NAMES = %w[
    javascript typescript react next.js vue nuxtjs svelte solidjs angular vite tailwindcss css html
    python rust c++ c# java kotlin swift ruby php elixir zig nodejs deno
    postgresql mysql sqlite redis mongodb graphql prisma django fastapi flask rails
    docker kubernetes terraform aws gcp azure linux webassembly cloudflare nginx
    openai llama ollama pytorch tensorflow
  ].freeze
  TECH_PHRASES = ["hugging face", "large language models", "machine learning",
                  "natural language processing", "artificial intelligence", "github actions"].freeze

  # Everyday words that are only trusted when they come from an explicit tag, never from free text.
  NOT_IN_TEXT = %w[node solid].freeze

  # Short acronyms are matched case-sensitively so "AI" counts but "ai" or "Said" does not.
  ACRONYMS = { "AI" => "artificial intelligence", "ML" => "machine learning", "JS" => "javascript" }.freeze

  # Generic community tags that say nothing about a technology.
  STOP_TAGS = %w[
    programming webdev beginners tutorial opensource open-source discuss productivity career
    showdev devjournal learning coding development software tech web practices video audio
    book release show ask announce culture law pdf news
  ].freeze

  DISPLAY = {
    "javascript" => "JavaScript", "typescript" => "TypeScript", "next.js" => "Next.js",
    "nodejs" => "Node.js", "nuxtjs" => "Nuxt", "solidjs" => "SolidJS", "postgresql" => "PostgreSQL",
    "tailwindcss" => "Tailwind CSS", "css" => "CSS", "html" => "HTML", "aws" => "AWS", "gcp" => "GCP",
    "c#" => "C#", "c++" => "C++", "php" => "PHP", "webassembly" => "WebAssembly", "graphql" => "GraphQL",
    "openai" => "OpenAI", "pytorch" => "PyTorch", "tensorflow" => "TensorFlow",
    "hugging face" => "Hugging Face", "large language models" => "LLMs",
    "artificial intelligence" => "AI", "natural language processing" => "NLP",
    "mongodb" => "MongoDB", "mysql" => "MySQL", "sqlite" => "SQLite", "fastapi" => "FastAPI",
    "github actions" => "GitHub Actions", "ci/cd" => "CI/CD", "nginx" => "NGINX"
  }.freeze

  ECOSYSTEMS = {
    "Frontend" => ["react", "next.js", "vue", "nuxtjs", "svelte", "solidjs", "typescript", "javascript",
                   "css", "html", "tailwindcss", "angular", "vite"],
    "AI / ML"  => ["python", "machine learning", "large language models", "natural language processing",
                   "pytorch", "tensorflow", "artificial intelligence", "hugging face", "llama", "openai", "ollama"],
    "Systems"  => ["rust", "go", "c++", "c", "linux", "webassembly", "zig"],
    "Backend"  => ["nodejs", "postgresql", "mysql", "sqlite", "redis", "mongodb", "docker", "prisma", "graphql",
                   "django", "fastapi", "flask", "rails", "elixir", "ruby", "java", "kotlin", "php", "express"],
    "DevOps"   => ["kubernetes", "docker", "terraform", "ci/cd", "github actions", "aws", "gcp", "azure",
                   "linux", "nginx", "cloudflare"]
  }.freeze
  ECOSYSTEM_NAMES = (["All"] + ECOSYSTEMS.keys).freeze

  def self.normalize(tag)
    t = tag.to_s.strip.downcase.sub(/-lang\z/, "")
    ALIASES.fetch(t, t)
  end

  def self.display(tag)
    DISPLAY[tag] || tag.split(/\s+/).map(&:capitalize).join(" ")
  end

  def self.ecosystems_for(tags)
    ECOSYSTEMS.select { |_, list| (list & tags).any? }.keys
  end

  # Normalised tags for an item: its own tags plus technologies named in the text.
  def self.tags_for(explicit_tags, text)
    explicit = Array(explicit_tags).map { |t| normalize(t) }
    (explicit + extract(text)).uniq.reject { |t| t.length < 2 || STOP_TAGS.include?(t) }
  end

  def self.extract(text)
    text = text.to_s
    found = (DETECTORS + ACRONYM_DETECTORS).select { |_, regex| regex.match?(text) }.map(&:first)
    found.uniq
  end

  # Plain \b fails next to + and #, so use explicit "not a letter or digit" guards.
  def self.word_regex(word, ignore_case: true)
    Regexp.new("(?<![A-Za-z0-9])#{Regexp.escape(word)}(?![A-Za-z0-9])", ignore_case ? Regexp::IGNORECASE : nil)
  end

  # Lists of [tag, regex] pairs (lists, not hashes, because "postgres" and "postgresql" share a tag).
  DETECTORS = begin
    words = (TECH_NAMES + TECH_PHRASES + ALIASES.keys.reject { |k| k.length < 3 }).uniq - NOT_IN_TEXT
    words.map { |w| [normalize(w), word_regex(w)] } +
      [["go", /(?<![A-Za-z0-9])(?:golang|Go (?:language|modules?|generics|1\.\d+))(?![A-Za-z0-9])/]]
  end.freeze

  ACRONYM_DETECTORS = ACRONYMS.map { |acr, tag| [tag, word_regex(acr, ignore_case: false)] }.freeze
end
