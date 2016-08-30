require_relative 'api'
require 'yaml'
require 'pry'

class Bot::Action
  include Bot::API

  def initialize(bot:, user_message:)
    @bot = bot
    @user_message = user_message
    @id = @user_message.chat.id

    @news_count_per_msg = 4
    @categories_count_per_msg = 3

    @messages = load_yaml_file(messages_path)
    @events = load_yaml_file(events_path)
  end

  def run
    case @user_message.text
      when '/start'
        track_event(@events['start'])
        send_response(@messages['start'])

      when '/help'
        track_event(@events['help'])
        send_response(@messages['help'])

      when '/author'
        track_event(@events['author'])
        send_response(@messages['author'])

      when /search/i
        query = @user_message.text.split(' ')[1..-1].join(' ')
        if query.empty?
          track_event(@events['try_search'])
          send_response(@messages['try_search'])
        else
          search_for_news(query)
        end

      when '/top'
        last_news_getter(@events['top'], "top")

      when '/now'
        last_news_getter(@events['now'], "now")

      when '/politics'
        news_category_getter(@events['politics'], "10", 86)

      when '/economics'
        news_category_getter(@events['economics'], "9", 39)

      when '/finance'
        news_category_getter(@events['finance'], "310", 41)

      when '/society'
        news_category_getter(@events['society'], "11", 43)

      when '/world'
        news_category_getter(@events['world'], "3", 49)

      when '/sports'
        news_category_getter(@events['sports'], "6", 53)

      when '/culture'
        news_category_getter(@events['culture'], "5", 57)

      when '/42'
        news_category_getter(@events['42'], "15", 65)

      when '/auto'
        news_category_getter(@events['auto'], "7", 69)

      when '/accidents'
        news_category_getter(@events['accidents'], "103", 73)

      when '/property'
        news_category_getter(@events['property'], "486", 79)

      when '/agenda'
        news_category_getter(@events['agenda'], "491", 98)

      when '/kurs'
        currencies_getter(@events['kurs'])
    end
  end

  private

    def send_response(response)
      @bot.api.sendMessage(chat_id: @id, text: response)
    end

    def track_event(event)
      @bot.track(event, @id, type_of_chat: @id)
    end

    def news_category_getter(event, category, category_id)
      track_event(event)
      response = news_category_handler(category, category_id)
      news = response['result'].each do |result|
        items = result['items']
        news_sender(items)
      end
    end

    # TODO make it to looks fuckable
    def search_for_news(query)
      track_event("#{@events['search_news']} #{query}")

      response = search_news(query)
      news = response['result']['items']

      if news.count.zero?
        track_event(@events['no_news_found'])
        return send_response(@messages['no_news_found'])
      end

      news_count = (1..3) === news.count ? news.count : @news_count_per_msg

      news_ids = (0..news_count).inject([]) do |ids, index|
        ids << news[index]['id']
      end

      news_response = get_news(news_ids)

      new_response = news_response['result']['items']
      news_sender(new_response)
    end

    def last_news_getter(event, category)
      track_event(event)
      response = main_handler(category)
      news = response['result']['items']
      news_sender(news)
    end

    def currencies_getter(event)
      track_event(event)
      response = finance_request
      currencies = response['exchangeRates']
      currencies_sender(currencies)
    end

    def news_sender(news)
      news[0..@news_count_per_msg].each do |item|
        send_response("#{item['title']} \n #{item['shortUrl']}")
      end
    end

    def currencies_sender(currencies)
      currencies[0..@categories_count_per_msg].each do |currency|
        send_response("#{currency['currencyCode']} - #{currency['nb']}")
      end
    end

    def load_yaml_file(file_path)
      YAML::load(IO.read(file_path))
    end

    def messages_path
      "config/messages.yml"
    end

    def events_path
      "config/events.yml"
    end

end
