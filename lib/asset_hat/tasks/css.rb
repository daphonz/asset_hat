namespace :asset_hat do
  namespace :css do

    # desc 'Adds mtimes to asset URLs in CSS'
    # task :add_asset_mtimes, :filename, :verbose do |t, args|
    #   if args.filename.blank?
    #     raise 'Usage: rake asset_hat:css:add_asset_mtimes[filename.css]' and return
    #   end
    #
    #   args.with_defaults :verbose => true
    #
    #   css = File.open(args.filename, 'r') { |f| f.read }
    #   css = AssetHat::CSS.add_asset_mtimes(css)
    #   File.open(args.filename, 'w') { |f| f.write css }
    #
    #   puts "- Added asset mtimes to #{args.filename}" if args.verbose
    # end

    desc 'Adds commit IDs to asset URLs in CSS for cache busting'
    task :add_asset_commit_ids, :filename, :verbose, :needs => :environment do |t, args|
      if args.filename.blank?
        raise 'Usage: rake asset_hat:css:add_asset_commit_ids[filename.css]' and return
      end

      args.with_defaults :verbose => true

      css = File.open(args.filename, 'r') { |f| f.read }
      css = AssetHat::CSS.add_asset_commit_ids(css)
      File.open(args.filename, 'w') { |f| f.write css }

      puts "- Added asset commit IDs to #{args.filename}" if args.verbose
    end

    desc 'Adds hosts to asset URLs in CSS'
    task :add_asset_hosts, :filename, :verbose, :needs => :environment do |t, args|
      if args.filename.blank?
        raise 'Usage: rake asset_hat:css:add_asset_hosts[filename.css]' and return
      end

      args.with_defaults :verbose => true

      asset_host = ActionController::Base.asset_host
      if asset_host.blank?
        raise "This environment (#{ENV['RAILS_ENV']}) doesn't have an `asset_host` configured."
        return
      end

      css = File.open(args.filename, 'r') { |f| f.read }
      css = AssetHat::CSS.add_asset_hosts(css, asset_host)
      File.open(args.filename, 'w') { |f| f.write css }

      puts "- Added asset hosts to #{args.filename}" if args.verbose
    end

    desc 'Minifies one CSS file'
    task :minify_file, :filepath, :verbose, :needs => :environment do |t, args|
      if args.filepath.blank?
        raise 'Usage: rake asset_hat:css:minify_file[path/to/filename.css]' and return
      end

      args.with_defaults :verbose => false
      min_options = {
        :engine => AssetHat.config['css']['engine']
      }.reject { |k,v| v.blank? }

      input   = File.open(args.filepath, 'r').read
      output  = AssetHat::CSS.minify(input, min_options)

      # Write minified content to file
      target_filepath = AssetHat::CSS.min_filepath(args.filepath)
      File.open(target_filepath, 'w') { |f| f.write output }

      # Print results
      puts "- Minified to #{target_filepath}" if args.verbose
    end

    desc 'Minifies one CSS bundle'
    task :minify_bundle, :bundle, :needs => :environment do |t, args|
      if args.bundle.blank?
        raise 'Usage: rake asset_hat:css:minify_bundle[application]' and return
      end

      config = AssetHat.config
      old_bundle_size = 0.0
      new_bundle_size = 0.0
      min_options = {
        :engine => config['css']['engine']
      }.reject { |k,v| v.blank? }

      # Get bundle filenames
      filenames = config['css']['bundles'][args.bundle]
      if filenames.empty?
        raise "No CSS files are specified for the #{args.bundle} bundle in #{AssetHat::CONFIG_FILEPATH}."
        return
      end
      filepaths = filenames.map do |filename|
        File.join('public', 'stylesheets', "#{filename}.css")
      end
      bundle_filepath = AssetHat::CSS.min_filepath(File.join(
        'public', 'stylesheets', 'bundles', "#{args.bundle}.css"))

      # Concatenate and process output
      output = ''
      asset_host = ActionController::Base.asset_host
      filepaths.each do |filepath|
        file_output = File.open(filepath, 'r').read
        old_bundle_size += file_output.size

        file_output = AssetHat::CSS.minify(file_output, min_options)
        file_output = AssetHat::CSS.add_asset_commit_ids(file_output)
        if asset_host.present?
          file_output = AssetHat::CSS.add_asset_hosts(file_output, asset_host)
        end

        new_bundle_size += file_output.size
        output << file_output + "\n"
      end
      FileUtils.makedirs(File.dirname(bundle_filepath))
      File.open(bundle_filepath, 'w') { |f| f.write output }

      # Print results
      percent_saved = 1 - (new_bundle_size / old_bundle_size)
      puts "\nWrote CSS bundle: #{bundle_filepath}"
      filepaths.each do |filepath|
        puts "        contains: #{filepath}"
      end
      if old_bundle_size > 0
        engine = "(Engine: #{min_options[:engine]})"
        puts "        MINIFIED: #{'%.1f' % (percent_saved * 100)}% #{engine}"
      end
    end

    desc 'Concatenates and minifies all CSS bundles'
    task :minify, :needs => :environment do
      # Get input bundles
      config = AssetHat.config
      if config['css'].blank? || config['css']['bundles'].blank?
        puts "You need to set up CSS bundles in #{AssetHat::CONFIG_FILEPATH}."
        exit
      end
      bundles = config['css']['bundles'].keys

      # Minify bundles
      bundles.each do |bundle|
        Rake::Task['asset_hat:css:minify_bundle'].reenable
        Rake::Task['asset_hat:css:minify_bundle'].invoke(bundle)
      end
    end

  end # namespace :css
end # namespace :asset_hat
