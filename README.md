# 目的
アプリケーションのパフォーマンスボトルネックを洗い出し改善する。

# 前提
| ソフトウェア     | バージョン    | 備考        |
|:---------------|:-------------|:------------|
| Ruby           |1.9.3p392     |       |
| Rails          |3.2.13        |       |
| sqlite3        |3.7.16.2      |       |
| ruby-prof      |0.13.0        |       |

# 構成
* [railsアプリの構築](#section1)
* [railsアプリのプロファイリング](#section2)
* [プロファイリング結果を分析する](#section3)

# 詳細
## <a name="section1">railsアプリの構築

    bash-3.2$ rails g scaffold blog title:string body:text
      invoke  active_record
      create    db/migrate/20130904061215_create_blogs.rb
      create    app/models/blog.rb
      invoke    test_unit
      create      test/unit/blog_test.rb
      create      test/fixtures/blogs.yml
      invoke  resource_route
       route    resources :blogs
      invoke  scaffold_controller
      create    app/controllers/blogs_controller.rb
      invoke    erb
      create      app/views/blogs
      create      app/views/blogs/index.html.erb
      create      app/views/blogs/edit.html.erb
      create      app/views/blogs/show.html.erb
      create      app/views/blogs/new.html.erb
      create      app/views/blogs/_form.html.erb
      invoke    test_unit
      create      test/functional/blogs_controller_test.rb
      invoke    helper
      create      app/helpers/blogs_helper.rb
      invoke      test_unit
      create        test/unit/helpers/blogs_helper_test.rb
      invoke  assets
      invoke    coffee
      create      app/assets/javascripts/blogs.js.coffee
      invoke    scss
      create      app/assets/stylesheets/blogs.css.scss
      invoke  scss
      create    app/assets/stylesheets/scaffolds.css.scss

    bash-3.2$ rake db:migrate
    ==  CreateBlogs: migrating ====================================================
    -- create_table(:blogs)
    -> 0.0012s
    ==  CreateBlogs: migrated (0.0012s) ===========================================

## <a name="section2">railsアプリのプロファイリング

### profile.rbを作成する
profile_test/config/environments/profile.rb


    ProfileTest::Application.configure do
        # Settings specified here will take precedence over those in config/application.rb

        # In the development environment your application's code is reloaded on
          # every request. This slows down response time but is perfect for development
          # since you don't have to restart the web server when you make code changes.
          config.cache_classes = true
          config.cache_template_loading = true

          # Log error messages when you accidentally call methods on nil.
          config.whiny_nils = true

          # Show full error reports and disable caching
          config.consider_all_requests_local       = true
          config.action_controller.perform_caching = true

          # Don't care if the mailer can't send
          config.action_mailer.raise_delivery_errors = false

          # Print deprecation notices to the Rails logger
          config.active_support.deprecation = :log

          # Only use best-standards-support built into browsers
          config.action_dispatch.best_standards_support = :builtin

          # Raise exception on mass assignment protection for Active Record models
          config.active_record.mass_assignment_sanitizer = :strict

          # Log the query plan for queries taking more than this (works
          # with SQLite, MySQL, and PostgreSQL)
          config.active_record.auto_explain_threshold_in_seconds = 0.5

          # Do not compress assets
          config.assets.compress = false

          # Expands the lines which load the assets
          config.assets.debug = true
        end

### gemfileを編集する

    group :profile do
      gem 'ruby-prof'
    end

### config.ruを編集する

    if Rails.env.profile?
      use Rack::RubyProf, :path => 'temp/profile'
    end

/temp/profileと指定するとファイルの絶対パスを指定することになりファイルが見つからないエラーが出る。
相対パスでRailsのプロジェクト内に配置したい場合は上記のファイルパス指定とする。

### database.ymを編集する
profile_test/config/database.yml

    profile:
      adapter: sqlite3
      database: db/development.sqlite3
      pool: 5
      timeout: 5000

念のため以下の処理も実行しておく

    bash-3.2$ rake db:migrate RAILS_ENV=profile

### プロファイリングコードを追記する
profile_test/app/controllers/

      def index

        # define mesurment type
        # as described: https://github.com/ruby-prof/ruby-prof#measurements
        RubyProf.measure_mode = RubyProf::PROCESS_TIME

        RubyProf.start

        # code to profile
        @blogs = Blog.all    

        result = RubyProf.stop
    
        respond_to do |format|
          format.html # index.html.erb
          format.json { render json: @blogs }
        end
      end

### その他
アセットパイプラインのためにプリコンパイル済みのアセットを作成しておく

    $ bundle exec rake assets:precompile RAILS_ENV=profile

### railsをprofile環境で起動する

    bash-3.2$ rails s -e profile

## <a name="section3">プロファイリング結果を分析する

### KCachegrindをインストールする。
Macの場合MacPortを使ってインストールする。
brewを使う場合はqcachegrindをインストールする。
qtも必要なのでなければ一緒にインストールする。

    bash-3.2$ brew install qcachegrind at

    bash-3.2$ qcachegrind

### Graphvizのインストール確認

    bash-3.2$ which dot
    /usr/local/bin/dot

なければインストール

    bash-3.2$ brew install graphviz

### KCachegrindに読み込ませるCallTreeファイルを出力するようにする
profile_test/config.ru

    if Rails.env.profile?
        use Rack::RubyProf, :path => 'temp/profile', :printers => {RubyProf::CallTreePrinter => 'Callgrid.out'}
    end

### 出力されたblogs-Callgrid.outファイルをKCachegrindに読み込ませる

# 参照
[ruby-prof/ruby-prof](https://github.com/ruby-prof/ruby-prof)

[ruby-profとKCacheGrindでプロファイル野郎になる](http://blog.mirakui.com/entry/20100919/rubyprof)

[Profiling Rails Applications](http://dpaluy.github.io/blog/2013/04/09/profiling-rails-applications/#ruby-prof)

[プリコンパイル済みのアセットを作成する](http://d.hatena.ne.jp/tetsuyai/20110920/1316504421)

[Homebrewを利用してKCachegrind(QCachegrind)をインストールし、PHPで使えるようにする](http://d.hatena.ne.jp/shigemk2/20120323/1332433728)

[KCachegrindを使ったコード改善](http://99blues.dyndns.org/blog/2010/07/kcachegrind/)
