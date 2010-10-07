class Person < ActiveRecord::Base
  require "#{RAILS_ROOT}/vendor/plugins/siteninja/siteninja_events/lib/person.rb"
  has_and_belongs_to_many :person_groups
  has_many :inquiries
  has_one :profile if CMS_CONFIG['modules']['profiles']
  has_one :user
  has_many :articles
  has_many :comments
  has_many :pages, :foreign_key => :author_id
  has_many :images, :as => :viewable, :dependent => :destroy
  has_many :features, :as => :featurable, :dependent => :destroy
  has_many :assets, :as => :attachable, :dependent => :destroy
  #Serial numbers for donations
  has_many :google_serials
  # validates_presence_of :first_name, :last_name
  validates_uniqueness_of :email, :message => "is an email address already in the system", :case_sensitive => false
  validates_format_of :email, :with => /^([0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*@([0-9a-zA-Z][-\w]*[0-9a-zA-Z]\.)+[a-zA-Z]{2,9})$/, :message => "is not a valid email address", :allow_blank => true
  #validates_format_of :email, :with => /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/, :message => "is not a valid email addres", :allow_blank => true
  named_scope :active, :conditions => { :active => true }
  default_scope :order => "last_name ASC"
  accepts_nested_attributes_for :user
  named_scope :unconfirmed, :conditions => {:confirmed => false}
  named_scope :confirmed, :conditions => {:confirmed => true}
  named_scope :author, :conditions => ["articles_count > ?", 0]
  attr_accessor :name
  #has_permalink :name
  has_attached_file :avatar, 
          {:styles => { 
            :thumb => "48x9999>",
            :square_thumb => "50x50#",
            :small => "138x9999>",
            :medium => "200x9999>", 
            :large => "250x9999>" 
          }}.merge(PAPERCLIP_OPS)
  # def to_param
  #     "#{self.id}-#{self.permalink}"
  #   end
  #   
  def name
    if self.first_name and self.last_name
      "#{self.first_name} #{self.last_name}"
    elsif self.last_name and !self.first_name
      self.last_name
    elsif self.first_name and !self.last_name
      self.first_name
    else
      ""
    end
  end

  def name_reversed
    if self.first_name and self.last_name
      "#{self.last_name}, #{self.first_name}"
    elsif self.last_name and !self.first_name
      self.last_name
    elsif self.first_name and !self.last_name
      self.first_name
    else
      ""
    end
  end

  def images_count
    self.images.size
  end
  
  def comments_count
    self.comments.size
  end
end

