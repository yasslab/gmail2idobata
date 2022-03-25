#!/usr/bin/env ruby
#coding: utf-8

require 'gmail' # for more info -> http://dcparker.github.com/ruby-gmail/
require 'pry'
require 'kconv'

Signal.trap(:INT){
  puts "logout Gmail ..."
  @gmail.logout if defined? @gmail
  puts "loged out!"
  exit
}

def attached_file_exist?(filename)
  if File.exist?(filename)
    puts "checked the given file '#{filename}' exists."
  else
    puts "it seems '#{filename}' doesn not exist."
    puts "check if the file really exists on the given path."
    exit
  end
end

USERNAME     = ENV['GMAIL_USERNAME']
PASSWORD     = ENV['GMAIL_PASSWORD']
IDOBATA_END  = ENV['IDOBATA_END']

# login, confirm, then send/cancel and logout
@gmail = Gmail.new(USERNAME, PASSWORD)

#emailsの引数には:all,:read,:unreadがある.
mails = @gmail.inbox.emails(:unread).each do |mail|
  text = ""
  is_html_format = false
  is_mitoujr_app = false

  #text  += "<li>件名:   #{mail.subject}</li>"
  #text  += "<li>日付:   #{mail.date}</li>"
  #text  += "<li>送信者: #{mail.from.first.to_a.first}</li>"
  #text  += "<li>受信者: #{mail.to}</li>" # この情報はいらない？

  if mail.subject.nil?
    text += "<b>件名なし</b><br>"
  else
    text += "<b>#{mail.subject.toutf8}</b><br>"
    is_mitoujr_app = true if text.include?('未踏ジュニア2022 応募フォーム')
  end

  begin
    #件名、日付、From、To、本文処理
    if !mail.text_part && !mail.html_part
      text += mail.body.decoded.encode('UTF-8', mail.charset, invalid: :replace, undef: :replace)
    elsif mail.html_part
      text += mail.html_part.decoded
      is_html_format = true
    elsif mail.text_part
      text += mail.text_part.decoded
    end
  rescue => e
    # エンコーディングで例外が発生したら、それも通知する
    text += e.message
  end

  post = text.gsub("\n", "").gsub("'", "\"")
  puts post
  puts "Is HTML format? => #{is_html_format}"

  if is_mitoujr_app == true
    require 'nokogiri'
    require 'net/http'

    doc = Nokogiri::HTML.parse(text)

    # Get Title & File (URL)
    title = doc.at("th[text()*='提案のタイトル']").next_element.text.strip
    file  = doc.at("a[href*='mitoujr.wufoo.com/cabinet']")['href']

    uri = URI.parse('https://mattermost.jr.mitou.org/hooks/huxdejyasbgdjgctwtxjf8udje')
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = JSON.dump({ text: ":new: 提案書: #{title} #{file}" })

    response = Net::HTTP.start(uri.hostname, uri.port, { use_ssl: uri.scheme == "https" }) do |http|
      http.request(request)
    end

    # response.code
    # response.body
    next
  end

  if is_html_format
    system("curl --data-urlencode 'source=#{post}' -d format=html #{IDOBATA_END}")
  else
    system("curl --data-urlencode 'source=#{post}' #{IDOBATA_END}")
  end
end

puts "No unread mails found."
puts ""
@gmail.logout
exit
