#!/usr/bin/env ruby

require 'desk'
require 'time' # lol, and patience

INBOX_ID = ENV['DESK_INBOX_ID']
TOO_MANY_DAYS = 2
SHOW_TOP = 10

def connect_to_desk
  Desk.configure do |config|
    config.support_email = ENV['DESK_EMAIL']
    config.subdomain = ENV['DESK_SUBDOMAIN']
    config.consumer_key = ENV['DESK_KEY']
    config.consumer_secret = ENV['DESK_SECRET']
    config.oauth_token = ENV['DESK_TOKEN']
    config.oauth_token_secret = ENV['DESK_TOKEN_SECRET']
  end
end

def get_case_data(cases)
  case_collection = {}
  while cases
    cases.each do |c|
      case_collection[c.id] = if c.status == 'new'
                                c.received_at
                              else
                                actually_received_at(c.id)
                              end
    end
    putc '.'
    cases = cases.next
  end
  case_collection.delete_if { |_id, received_at| received_at.nil? }
end

def display_cases(cases, threshold)
  cases.delete_if { |_c, received_at| time_elapsed(received_at)[0] < threshold }
  cases = cases.sort_by { |_case_id, received_at| received_at }
  cases.first(SHOW_TOP).each do |case_id, received_at|
    days, hours = time_elapsed(received_at)
    puts "case ##{case_id}: no response for #{days} days, #{hours} hours"
  end
end

def actually_received_at(case_id)
  replies = Desk.list_case_replies(case_id)
  replies = replies.sort_by { |r| r[:updated_at] }.reverse
  replies.delete_if { |r| r.status == 'draft' }
  if replies.count > 0
    replies.each do |r|
      r.direction == 'in' ? @date = r.updated_at : break
    end
  else
    @date = Desk.case(case_id).received_at
  end
  @date
end

def time_elapsed(date)
  t = Time.now - Time.iso8601(date)
  mm, _ss = t.divmod(60)
  hh, _mm = mm.divmod(60)
  hh.divmod(24)
end

system 'clear'
connect_to_desk
print 'deep-scanning inbox'

inbox = Desk.filter_cases(INBOX_ID)
cases = get_case_data(inbox)

puts "\n\nmost neglected cases"
puts "====================\n\n"

display_cases(cases, TOO_MANY_DAYS)
