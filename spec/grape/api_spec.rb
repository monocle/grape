require 'spec_helper'

describe Grape::API do
  subject { Class.new(Grape::API) }
  before { subject.default_format :txt }

  def app; subject end

  describe '.prefix' do
    it 'should route through with the prefix' do
      subject.prefix 'awesome/sauce'
      subject.get :hello do
        "Hello there."
      end

      get 'awesome/sauce/hello'
      last_response.body.should eql "Hello there."

      get '/hello'
      last_response.status.should eql 404
    end
  end

  describe '.version' do
    it 'should set the API version' do
      subject.version 'v1'
      subject.get :hello do
        "Version: #{request.env['api.version']}"
      end

      get '/v1/hello'
      last_response.body.should eql "Version: v1"
    end

    it 'should add the prefix before the API version' do
      subject.prefix 'api'
      subject.version 'v1'
      subject.get :hello do
        "Version: #{request.env['api.version']}"
      end

      get '/api/v1/hello'
      last_response.body.should eql "Version: v1"
    end

    it 'should be able to specify version as a nesting' do
      subject.version 'v2'
      subject.get '/awesome' do
        "Radical"
      end

      subject.version 'v1' do
        get '/legacy' do
          "Totally"
        end
      end

      get '/v1/awesome'
      last_response.status.should eql 404
      get '/v2/awesome'
      last_response.status.should eql 200
      get '/v1/legacy'
      last_response.status.should eql 200
      get '/v2/legacy'
      last_response.status.should eql 404
    end

    it 'should be able to specify multiple versions' do
      subject.version 'v1', 'v2'
      subject.get 'awesome' do
        "I exist"
      end

      get '/v1/awesome'
      last_response.status.should eql 200
      get '/v2/awesome'
      last_response.status.should eql 200
      get '/v3/awesome'
      last_response.status.should eql 404
    end

    it 'should allow the same endpoint to be implemented for different versions' do
      subject.version 'v2'
      subject.get 'version' do
        request.env['api.version']
      end

      subject.version 'v1' do
        get 'version' do
          "version " + request.env['api.version']
        end
      end

      get '/v2/version'
      last_response.status.should == 200
      last_response.body.should == 'v2'
      get '/v1/version'
      last_response.status.should == 200
      last_response.body.should == 'version v1'
    end

  end

  describe '.namespace' do
    it 'should be retrievable and converted to a path' do
      subject.namespace :awesome do
        namespace.should == '/awesome'
      end
    end

    it 'should come after the prefix and version' do
      subject.prefix :rad
      subject.version :v1

      subject.namespace :awesome do
        compile_path('hello').should == '/rad/:version/awesome/hello(.:format)'
      end
    end

    it 'should cancel itself after the block is over' do
      subject.namespace :awesome do
        namespace.should == '/awesome'
      end

      subject.namespace.should == '/'
    end

    it 'should be stackable' do
      subject.namespace :awesome do
        namespace :rad do
          namespace.should == '/awesome/rad'
        end
        namespace.should == '/awesome'
      end
      subject.namespace.should == '/'
    end

    it 'should be callable with nil just to push onto the stack' do
      subject.namespace do
        version 'v2'
        compile_path('hello').should == '/:version/hello(.:format)'
      end
      subject.send(:compile_path, 'hello').should == '/hello(.:format)'
    end

    %w(group resource resources).each do |als|
      it "`.#{als}` should be an alias" do
        subject.send(als, :awesome) do
          namespace.should ==  "/awesome"
        end
      end
    end
  end

  describe '.route' do
    it 'should allow for no path' do
      subject.namespace :votes do
        get do
          "Votes"
        end

        post do
          "Created a Vote"
        end
      end

      get '/votes'
      last_response.body.should eql 'Votes'
      post '/votes'
      last_response.body.should eql 'Created a Vote'
    end

    it 'should allow for multiple paths' do
      subject.get("/abc", "/def") do
        "foo"
      end

      get '/abc'
      last_response.body.should eql 'foo'
      get '/def'
      last_response.body.should eql 'foo'
    end

    it 'should allow for format' do
      subject.get("/abc") do
        "json"
      end

      get '/abc.json'
      last_response.body.should eql '"json"'
    end

    it 'should allow for format in namespace with no path' do
      subject.namespace :abc do
        get do
          "json"
        end
      end

      get '/abc.json'
      last_response.body.should eql '"json"'
    end

    it 'should allow for multiple verbs' do
      subject.route([:get, :post], '/abc') do
        "hiya"
      end

      get '/abc'
      last_response.body.should eql 'hiya'
      post '/abc'
      last_response.body.should eql 'hiya'
    end

    it 'should allow for multipart paths' do


      subject.route([:get, :post], '/:id/first') do
        "first"
      end


      subject.route([:get, :post], '/:id') do
        "ola"
      end
      subject.route([:get, :post], '/:id/first/second') do
        "second"
      end


      get '/1'
      last_response.body.should eql 'ola'
      post '/1'
      last_response.body.should eql 'ola'
      get '/1/first'
      last_response.body.should eql 'first'
      post '/1/first'
      last_response.body.should eql 'first'
      get '/1/first/second'
      last_response.body.should eql 'second'

    end

    it 'should allow for :any as a verb' do
      subject.route(:any, '/abc') do
        "lol"
      end

      %w(get post put delete).each do |m|
        send(m, '/abc')
        last_response.body.should eql 'lol'
      end
    end

    verbs = %w(post get head delete put)
    verbs.each do |verb|
      it "should allow and properly constrain a #{verb.upcase} method" do
        subject.send(verb, '/example') do
          verb
        end
        send(verb, '/example')
        last_response.body.should eql verb
        # Call it with a method other than the properly constrained one.
        send(verbs[(verbs.index(verb) + 1) % verbs.size], '/example')
        last_response.status.should eql 404
      end
    end

    it 'should return a 201 response code for POST by default' do
      subject.post('example') do
        "Created"
      end

      post '/example'
      last_response.status.should eql 201
      last_response.body.should eql 'Created'
    end
  end

  context 'custom middleware' do
    class PhonyMiddleware
      def initialize(app, *args)
        @args = args
        @app = app
      end

      def call(env)
        env['phony.args'] ||= []
        env['phony.args'] << @args
        @app.call(env)
      end
    end

    describe '.middleware' do
      it 'should include middleware arguments from settings' do
        subject.stub!(:settings_stack).and_return [{:middleware => [[PhonyMiddleware, 'abc', 123]]}]
        subject.middleware.should eql [[PhonyMiddleware, 'abc', 123]]
      end

      it 'should include all middleware from stacked settings' do
        subject.stub!(:settings_stack).and_return [
          {:middleware => [[PhonyMiddleware, 123],[PhonyMiddleware, 'abc']]},
          {:middleware => [[PhonyMiddleware, 'foo']]}
        ]

        subject.middleware.should eql [
          [PhonyMiddleware, 123],
          [PhonyMiddleware, 'abc'],
          [PhonyMiddleware, 'foo']
        ]
      end
    end

    describe '.use' do
      it 'should add middleware' do
        subject.use PhonyMiddleware, 123
        subject.middleware.should eql [[PhonyMiddleware, 123]]
      end

      it 'should not show up outside the namespace' do
        subject.use PhonyMiddleware, 123
        subject.namespace :awesome do
          use PhonyMiddleware, 'abc'
          middleware.should == [[PhonyMiddleware, 123],[PhonyMiddleware, 'abc']]
        end

        subject.middleware.should eql [[PhonyMiddleware, 123]]
      end

      it 'should actually call the middleware' do
        subject.use PhonyMiddleware, 'hello'
        subject.get '/' do
          env['phony.args'].first.first
        end

        get '/'
        last_response.body.should eql 'hello'
      end
    end
  end
  describe '.basic' do
    it 'should protect any resources on the same scope' do
      subject.http_basic do |u,p|
        u == 'allow'
      end
      subject.get(:hello){ "Hello, world."}
      get '/hello'
      last_response.status.should eql 401
      get '/hello', {}, 'HTTP_AUTHORIZATION' => encode_basic('allow','whatever')
      last_response.status.should eql 200
    end

    it 'should be scopable' do
      subject.get(:hello){ "Hello, world."}
      subject.namespace :admin do
        http_basic do |u,p|
          u == 'allow'
        end

        get(:hello){ "Hello, world." }
      end

      get '/hello'
      last_response.status.should eql 200
      get '/admin/hello'
      last_response.status.should eql 401
    end

    it 'should be callable via .auth as well' do
      subject.auth :http_basic do |u,p|
        u == 'allow'
      end

      subject.get(:hello){ "Hello, world."}
      get '/hello'
      last_response.status.should eql 401
      get '/hello', {}, 'HTTP_AUTHORIZATION' => encode_basic('allow','whatever')
      last_response.status.should eql 200
    end
  end

  describe '.helpers' do
    it 'should be accessible from the endpoint' do
      subject.helpers do
        def hello
          "Hello, world."
        end
      end

      subject.get '/howdy' do
        hello
      end

      get '/howdy'
      last_response.body.should eql 'Hello, world.'
    end

    it 'should be scopable' do
      subject.helpers do
        def generic
          'always there'
        end
      end

      subject.namespace :admin do
        helpers do
          def secret
            'only in admin'
          end
        end

        get '/secret' do
          [generic, secret].join ':'
        end
      end

      subject.get '/generic' do
        [generic, respond_to?(:secret)].join ':'
      end

      get '/generic'
      last_response.body.should eql 'always there:false'
      get '/admin/secret'
      last_response.body.should eql 'always there:only in admin'
    end

    it 'should be reopenable' do
      subject.helpers do
        def one
          1
        end
      end

      subject.helpers do
        def two
          2
        end
      end

      subject.get 'howdy' do
        [one, two]
      end

      lambda{get '/howdy'}.should_not raise_error
    end
  end

  describe '.scope' do
    it 'should scope the various settings' do
      subject.version 'v2'

      subject.scope :legacy do
        version 'v1'

        get '/abc' do
          version
        end
      end

      subject.get '/def' do
        version
      end

      get '/v2/abc'
      last_response.status.should eql 404
      get '/v1/abc'
      last_response.status.should eql 200
      get '/v1/def'
      last_response.status.should eql 404
      get '/v2/def'
      last_response.status.should eql 200
    end
  end

  describe ".callback" do
    before do
      subject.default_format :json
      subject.prefix 'api'
    end

    it "when defined, wraps the response body (JSON only) in the callback" do
      subject.callback 'my_callback'
      subject.get :hello do
        { 'howdy' => 'hey' }
      end

      get 'api/hello?who_dat=me&my_callback=sup'
      last_response.body.should == "sup({\"howdy\":\"hey\"});"
    end
  end
end
