#!/usr/local/bin/ruby
# Niklaus Giger, November 2016
# A simple example on how to use SBSM with webrick
require 'sbsm/logger'
require 'sbsm/app'

root_dir = File.expand_path(File.join(__FILE__, '..', '..'))
TEST_LOGGER = ChronoLogger.new(File.join(root_dir, 'test.log'))
SBSM.logger=TEST_LOGGER

TEST_APP_URI  = 'druby://localhost:9876'
SERVER_NAME = 'localhost:9878'
TEST_COOKIE_NAME = 'test-cookie'

# Some string shared with the unit test
HOME_HTML_CONTENT = 'Überall zu Hause' # mit UTF-8!
ABOUT_HTML_CONTENT = 'About SBSM: TDD ist great!'
REDIRECT_HTML_CONTENT = 'This content should be redirected to feedback'
FEEDBACK_HTML_CONTENT = 'Give us your feedback about SBSM'
CONFIRM_HTML_CONTENT = 'Please confirm your feedback'
SENT_HTML_CONTENT = 'Thanks for you feedback! Hope to see you soon'

begin
  require 'pry'
rescue LoadError
end

module Demo
  class GlobalState < SBSM::State
  end
  class Validator < SBSM::Validator
    EVENTS = %i{
      home
      about
      redirect
      feedback
    }
    STRINGS = %i{
      anrede
      name
    }
  end

  class HomeState < GlobalState
    EVENTS = %i{
      home
      about
      redirect
      feedback
    }
    @@class_counter = 0
    def initialize(session, user)
      SBSM.info "HomeState #{session}"
      @session = session
      @member_counter = 0
      super(session, user)
    end
    def to_html(cgi)
      @@class_counter += 1
      @member_counter += 1
      SBSM.info "@member_counter now #{@member_counter}"
      info = ["State is Home" ,
      "pid is #{Process.pid}",
      "request_path is #{@request_path}" ,
      "@member_counter is #{@member_counter}",
      "@@class_counter is #{@@class_counter}",
      HOME_HTML_CONTENT,
      ]
      info.join("\n")
    end
  end
  class AboutView
    def initialize(model, session)
    end
    def to_html(cgi)
      'About SBSM: TDD ist great!'
    end
  end
  class AboutState < GlobalState
    DIRECT_EVENT = :about
    VIEW = AboutView
    def initialize(session, user)
      SBSM.info "AboutState #{session}"
      super(session, user)
    end
  end
  class RedirectState < GlobalState
    DIRECT_EVENT = :redirect
    def initialize(session, user)
      SBSM.info "RedirectState #{session}"
      super(session, user)
    end
    def http_headers
     {
        'Status'   => '303 See Other',
        'Location' => 'feedback',
      }
    end
    def to_html(cgi)
      REDIRECT_HTML_CONTENT
    end
  end
  class FeedbackMail
    attr_accessor :errors
    attr_reader :email, :anrede, :name, :vorname, :firma, :adresse, :ort,
                :telefon, :bestell_diss, :bestell_pedi, :text

    def initialize(session)
      @errors       = []
      @session      = session
      @email        = @session.user_input(:email)
      @anrede       = @session.user_input(:anrede)
      @name         = @session.user_input(:name)
      @vorname      = @session.user_input(:vorname)
      @firma        = @session.user_input(:firma)
      @adresse      = @session.user_input(:adresse)
      @ort          = @session.user_input(:ort)
      @telefon      = @session.user_input(:telefon)
      @bestell_diss = @session.user_input(:bestell_diss)
      @bestell_pedi = @session.user_input(:bestell_pedi)
      @text         = @session.user_input(:text)
    end

    def body
      width = 25
      body = []
      body << 'Email-Adresse:'.ljust(width) + @email
      body << 'Anrede:'.ljust(width) + @anrede
      body << 'Name:'.ljust(width) + @name
      body << 'Vorname:'.ljust(width) + @vorname
      body << 'Firma:'.ljust(width) + @firma
      body << 'Adresse:'.ljust(width) + @adresse
      body << 'Ort:'.ljust(width) + @ort
      body << 'Telefon:'.ljust(width) + @telefon
      body << 'Bestellung Dissertion:'.ljust(width) + @bestell_diss
      body << 'Bestellung Pädiatrie:'.ljust(width) + @bestell_pedi
      body << 'Ihre Mitteilung:'.ljust(width) + @text
      body.join("\n")
    end

    def error?(key)
      @errors.include?(key)
    end

    def ready?
      unless @email
        false
      elseustomized
        true
      end
    end

    def do_sendmail
      smtp = Net::SMTP.new(Steinwies.config.mailer['server'])
      smtp.start(
        Steinwies.config.mailer['domain'],
        Steinwies.config.mailer['user'],
        Steinwies.config.mailer['pass'],
        Steinwies.config.mailer['auth']
      )
      smtp.ready(@email, Steinwies.config.mailer['to']) {  |a|
        a.write("Content-Type: text/plain; charset='UTF-8'\n")
        a.write("Subject: Email von Deiner Webseite.\n")
        a.write("\n")
        a.write(body)
      }
    end
  end
  class SentState < GlobalState
    def to_html(cgi)
      SENT_HTML_CONTENT
    end
  end
  class ConfirmState < GlobalState
    DIRECT_EVENT = :confirm

    def sendmail
      @model.do_sendmail
      SentState.new(@session, nil)
    end

    def back
      KontaktState.new(@session, @model)
    end
    def to_html(cgi)
      CONFIRM_HTML_CONTENT
    end
  end
  class FeedbackState < GlobalState
    DIRECT_EVENT = :feedback

    def initialize(session, model)
      SBSM.info "state/feedback.rb #{__LINE__} Steinwies init #{session.class} model #{model.class}"
      super(session, model)
    end
    def to_html(cgi)
      FEEDBACK_HTML_CONTENT
    end
    def confirm
      mail = FeedbackMail.new(@session)
      puts "state/feedback.rb #{__LINE__} confirm #{mail.inspect} #{mail.ready?.inspect}"
      if mail.ready?
        ConfirmState.new(@session, mail)
      else
        puts "Pushed error"
        mail.errors.push(:email)
        @model = mail
        self
      end
    end
  end
  class GlobalState < SBSM::State
    GLOBAL_MAP = {
      :home         => Demo::HomeState,
      :about        => Demo::AboutState,
      :redirect     => Demo::RedirectState,
      :feedback     => Demo::FeedbackState,
    }
    DIRECT_EVENT = nil
    # VIEW         = ::Demo::Home
  end
  class Session < SBSM::Session
    DEFAULT_STATE    = HomeState
  end

  class SimpleSBSM < SBSM::App
    def initialize
      SBSM.info "SimpleSBSM.new"
      super(app: self)
    end
  end
  class SimpleRackInterface < SBSM::RackInterface
    SESSION = Session

    def initialize(validator: SBSM::Validator.new,
                   trans_handler: SBSM::TransHandler.instance,
                   cookie_name: nil,
                   session_class: SESSION)
      SBSM.info "SimpleRackInterface.new SESSION #{SESSION}"
      super(app: SimpleSBSM,
            validator: validator,
            trans_handler: trans_handler,
            cookie_name: cookie_name,
            session_class: session_class)
    end
  end
end
