require 'mail'
require 'json'
require 'base64'
load 'message_formatter.rb'
module GmailArchiver
  class FetchData
    attr_accessor :seqno, :uid, :mail, :envelope, :rfc822, :size, :flags

    def initialize(x)
      @seq = x.seqno
      @uid = x.attr['UID']
      @message_id = x.attr["MESSAGE-ID"]
      @envelope = x.attr["ENVELOPE"]
      @size = x.attr["RFC822.SIZE"] # not sure what units this is
      @flags = x.attr["FLAGS"]  # e.g. [:Seen]
      @rfc822 = x.attr['RFC822']
      @mail = Mail.new(x.attr['RFC822'])
    end
    
    def attributes
      {
        :seq => @seq,
        :uid => @uid,
        :date => Time.parse(@envelope.date).utc.iso8601,
        :subject => format_subject(@envelope.subject),
        :from => format_recipients(@envelope.from),
        :to => format_recipients(@envelope.to),
        :body => message,
        :size => @size,
        :flags => @flags,
        "_id" => gmail_plus_label,
        :raw_mail => @mail.to_s,
        '_attachments' => format_attachments
      }.delete_if{|k,v| v == ""}
    end

    def gmail_plus_label
      format_recipients(@envelope.to)[0].split("+")[1].split("@")[0]
    end

    def subject
      envelope.subject
    end

    def sender
      envelope.from.first
    end

    def in_reply_to
      envelope.in_reply_to 
    end

    def message_id
      envelope.message_id
    end

    # http://www.ruby-doc.org/stdlib/libdoc/net/imap/rdoc/classes/Net/IMAP.html
    #

    def message
      formatter = MessageFormatter.new(@mail)
      message_text = <<-EOF
#{format_headers(formatter.extract_headers)}

#{formatter.process_body}
EOF
    end
    
    def format_attachments
      attachments = {}
      if @mail.attachments.length > 0
        @mail.attachments.each do |attachment|
          begin
            attachments[attachment.filename] = {
                content_type: attachment.content_type.to_s.split("\;")[0],
                data: Base64.encode64(attachment.body.decoded)
              }
          rescue Exception => e
            puts "unable to process #{attachment.filename}"
          end
        end
      end
      attachments
    end

    def format_subject(subject)
      Mail::Encodings.unquote_and_convert_to((subject || ''), 'UTF-8')
    end

    def format_recipients(recipients)
      recipients ? recipients.map{|m| [m.mailbox, m.host].join('@')} : ""
    end

    def format_parts_info(parts)
      lines = parts.select {|part| part !~ %r{text/plain}}
      if lines.size > 0
        "\n#{lines.join("\n")}"
      end
    end

    def format_headers(hash)
      lines = []
      hash.each_pair do |key, value|
        if value.is_a?(Array)
          value = value.join(", ")
        end
        lines << "#{key.gsub("_", '-')}: #{value}"
      end
      lines.join("\n")
    end

  end
end