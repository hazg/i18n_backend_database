def load_default_locales(path_to_file=nil)
  path_to_file ||= File.join(File.dirname(__FILE__), "../data", "locales.yml")
  data = YAML::load(IO.read(path_to_file))
  data.each do |code, y|
    Locale.create({:code => code, :name => y["name"]})
  end
end

def load_from_yml(file_name)
  data = YAML::load(IO.read(file_name))
  data.each do |code, translations| 
    locale = Locale.find_or_create_by_code(code)
    backend = I18n::Backend::Simple.new
    keys = extract_i18n_keys(translations)
    keys.each do |key|
      value = backend.send(:lookup, code, key)

      pluralization_index = 1

      if key.ends_with?('.one')
        key.gsub!('.one', '')
      end

      if key.ends_with?('.other')
        key.gsub!('.other', '')
        pluralization_index = 0
      end

      if value.is_a?(Array)
        value.each_with_index do |v, index|
          create_translation(locale, "#{key}.#{index}", pluralization_index, v.to_s) unless v.nil?
        end
      else
        create_translation(locale, key, pluralization_index, value)
      end

    end
  end
end

def create_translation(locale, key, pluralization_index, value)
  translation = locale.translations.find_by_key_and_pluralization_index(Translation.hk(key), pluralization_index) # find existing record by hash key
  translation = locale.translations.build(:key =>key, :pluralization_index => pluralization_index) unless translation # or build new one with raw key
  translation.value = value
  translation.save!
end

def extract_i18n_keys(hash, parent_keys = [])
  hash.inject([]) do |keys, (key, value)|
    full_key = parent_keys + [key]
    if value.is_a?(Hash)
      # Nested hash
      keys += extract_i18n_keys(value, full_key)
    elsif value.present?
      # String leaf node
      keys << full_key.join(".")
    end
    keys
  end
end

namespace :i18n do
  desc 'Clear cache'
  task :clear_cache => :environment do
    I18n.backend.cache_store.clear
  end

  desc 'Install admin panel assets'
  task :install_admin_assets => :environment do
    images_dir     = Rails.root + '/public/images/'
    javascripts_dir = Rails.root + '/public/javascripts/'
    images  = Dir[File.join(File.dirname(__FILE__), '..') + '/lib/public/images/*.*']
    scripts = Dir[File.join(File.dirname(__FILE__), '..') + '/lib/public/javascripts/*.*']
    FileUtils.cp(images,  images_dir)
    FileUtils.cp(scripts, javascripts_dir)
  end

  namespace :populate do
    desc 'Populate the locales and translations tables from all Rails Locale YAML files. Can set LOCALE_YAML_FILES to comma separated list of files to overide'
    task :from_rails => :environment do
      yaml_files = ENV['LOCALE_YAML_FILES'] ? ENV['LOCALE_YAML_FILES'].split(',') : I18n.load_path
      yaml_files.each do |file|
        load_from_yml file
      end
    end

    desc 'Populate default locales'
    task :load_default_locales => :environment do
      load_default_locales(ENV['LOCALE_FILE'])
    end
  end
end
