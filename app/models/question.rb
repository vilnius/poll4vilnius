class Question < ActiveRecord::Base
  attr_accessible :poll_id, :question_type, :text, :parent_option_id, :sequence, :options_attributes, :follow_up_options_attributes
  has_many :responses
  has_many :options, :dependent => :destroy
  has_many :follow_up, :through => :options
  has_many :follow_up_options, :class_name => "Option", :foreign_key => "question_id", :dependent => :destroy
  has_many :follow_up_responses, :through => :options
  accepts_nested_attributes_for :options, :follow_up_options, :reject_if => :all_blank, :allow_destroy => true


  belongs_to :poll
  belongs_to :option, :foreign_key => "parent_option_id"

  validates :question_type, :inclusion => { :in => %w(MULTI OPEN YN), :message => "%{value} is not a valid question type" }  
  validates_presence_of :question_type#, :poll_id
  validates_presence_of :text

  def get_follow_up
    if self.options.length > 0
      self.options.each do |o|
        return o.follow_up[0] unless o.follow_up.blank?
      end
    end
    return false
  end

  def get_matching_option(response)
    puts "getting matching option for #{response}"
    if response
      self.options.each do |o|
        if o.match?(response)
          return o.text
        end
      end
    end
    false
  end

  def response_histogram
    excludes = [false," ","","a","about","above","after","again","against","all","am","an","and","any","are","aren't","as","at","be","because","been","before","being","below","between","both","but","by","can't","cannot","could","couldn't","did","didn't","do","does","doesn't","doing","don't","down","during","each","few","for","from","further","had","hadn't","has","hasn't","have","haven't","having","he","he'd","he'll","he's","her","here","here's","hers","herself","him","himself","his","how","how's","i","i'd","i'll","i'm","i've","if","in","into","is","isn't","it","it's","its","itself","let's","me","more","most","mustn't","my","myself","no","nor","not","of","off","on","once","only","or","other","ought","our","ours","ourselves","out","over","own","same","shan't","she","she'd","she'll","she's","should","shouldn't","so","some","such","than","that","that's","the","their","theirs","them","themselves","then","there","there's","these","they","they'd","they'll","they're","they've","this","those","through","to","too","under","until","up","very","was","wasn't","we","we'd","we'll","we're","we've","were","weren't","what","what's","when","when's","where","where's","which","while","who","who's","whom","why","why's","with","won't","would","wouldn't","you","you'd","you'll","you're","you've","your","yours","yourself","yourselves"]
    r = self.responses
    puts "response histogramming time: #{responses}"
    if r.length > 0
      # create an array with all the words from all the responses
      if self.options.empty?
        words = r.map{ |rs| rs.response.downcase.split(/[^A-Za-z0-9\-]/)}.flatten
      else
        words = r.map{ |rs| self.get_matching_option(rs.response) }
      end

      # reduce the words array to a set of word => frequency pairs
      hist = words.reduce(Hash.new(0)){|set, val| set[val] += 1; set}
      # sort the hash (into an array) by frequency, descending
      hist_sorted = hist.sort{|a,b| b[1] <=> a[1]}
      puts "hist_sorted #{hist_sorted}"

      # return the histogram after filtering out excluded words
      return hist_sorted.select{|i| !excludes.include?(i[0]) && i[0].length > 1}
    end
  end
  # determines if a follow_up was triggered by a past response
  def follow_up_triggered?(phone)
    @follow = self.get_follow_up
    @response = self.responses.where(:from=>phone).last
    if @follow && @response
      return true if @follow.parent_option.match?(@response.response)
    end
    false
  end

  def send_follow_up?(response)
    @follow = self.get_follow_up
    if @follow
      return true if @follow.parent_option.match?(response)
    end
    false
  end

  def valid_response?(response)
    if self.question_type == 'OPEN'
      return true
    else
      self.options.each do |o|
        return true if o.match?(response)
      end
    end
    false
  end

  def parent_option
    Option.find(self.parent_option_id)
  end

  def multi?
    return self.question_type == 'MULTI'
  end

  def yn?
    return self.question_type == 'YN'
  end

  def open?
    return self.question_type == 'OPEN'
  end

  def answered?(from)
    return self.responses.where(from: from).length > 0
  end

  #returns a nicely formatted string for sending via sms
  def to_sms
    ret = "#{self.text} "
    if self.question_type == 'YN'
      ret += 'Reply with Yes or No'
    elsif self.question_type == 'MULTI'
      ret << 'Reply with letter: '
      opts = []
      self.options.each do |o|
        opts << "#{o.value.upcase} #{o.text}"
      end
      ret << opts.join(' / ')
    end
    return ret
  end
end
