require "rails_helper"

RSpec.describe PriceMailer, type: :mailer do
  describe "price_changed" do
    let(:mail) { PriceMailer.price_changed }

    it "renders the headers" do
      expect(mail.subject).to eq("Price changed")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

  describe "failed" do
    let(:mail) { PriceMailer.failed }

    it "renders the headers" do
      expect(mail.subject).to eq("Failed")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

end
