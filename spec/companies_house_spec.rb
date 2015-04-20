require 'spec_helper'

describe CompaniesHouse do

  before(:each) do
    @companies_house = CompaniesHouse.new("test-file.csv")
  end

  it "parses an address from a CSV row correctly" do
    stub_request(:post, "http://sorting-office.openaddressesuk.org/address").
      with(:body => "address=10%20DOWNING%20STREET%2C%20%2C%20LONDON%2C%20SW1A%202AA").
      to_return(body: File.read(File.join("spec", "fixtures", "sorting-office.json")))

      allow(@companies_house).to receive(:build_provenance) { nil }

    row = {
      4 => "10 DOWNING STREET",
      5 => "",
      6 => "LONDON",
      7 => "",
      8 => "",
      9 => "SW1A 2AA",
      14 => "11/09/2010",
      18 => "11/09/2011",
      21 => "11/09/2012"
    }

    expected = {
      saon: nil,
      paon: "10",
      street: "Downing Street",
      locality: nil,
      town: "London",
      postcode: "SW1A 2AA",
      valid_at: DateTime.parse("2012-09-11T00:00:00"),
      provenance: nil
    }.to_json

    expect { @companies_house.parse_address(row) }.to output(expected + "\n").to_stdout
  end

  it "doesn't crap out on a bad CSV" do
    filename = File.join("spec", "fixtures", "bad.csv")

    expect(@companies_house).to receive(:parse_address).exactly(15).times
    expect(Turbotlib).to receive(:log).with(/Bad line found at line 5 \- "TOTS2TEENS LTD"/)

    @companies_house.parse_csv(filename)
  end

  it "creates the correct provenance" do
    Timecop.freeze("2014-01-01 16:20:00")
    response = JSON.parse(File.read(File.join("spec", "fixtures", "sorting-office.json")))
    allow(@companies_house).to receive(:current_sha) { "asdasdasdsa" }

    prov = @companies_house.build_provenance(response)

    expect(prov[:activity][:derived_from].first[:urls].first).to eq("http://download.companieshouse.gov.uk/test-file.csv")
    expect(prov[:activity][:executed_at]).to eq(DateTime.parse("2014-01-01 16:20:00"))
    expect(prov[:activity][:derived_from].count).to eq(4)
    expect(prov[:activity][:derived_from][1][:urls].first).to eq("http://alpha.openaddressesuk.org/streets/PXxwpD")
    expect(prov[:activity][:derived_from][2][:urls].first).to eq("https://alpha.openaddressesuk.org/towns/4194LO")
    expect(prov[:activity][:derived_from][3][:urls].first).to eq("https://alpha.openaddressesuk.org/postcodes/EMCYvD")
    expect(prov[:activity][:derived_from][1][:processing_script]).to eq("https://github.com/oa-bots/companies_house/tree/asdasdasdsa/scraper.rb")
    expect(prov[:activity][:derived_from][1][:downloaded_at]).to eq(DateTime.parse("2014-01-01 16:20:00"))

    Timecop.return
  end

  it "retries requests to sorting office if there's a temporary issue" do
    stub_request(:post, "http://sorting-office.openaddressesuk.org/address").
      with(:body => "address=10%20DOWNING%20STREET%2C%20%2C%20LONDON%2C%20SW1A%202AA").
      to_return(status: 404, body: "").times(3).then.
      to_return(body: File.read(File.join("spec", "fixtures", "sorting-office.json")))

    allow(@companies_house).to receive(:sleep) { nil }

    response = @companies_house.request_with_retries("http://sorting-office.openaddressesuk.org/address", "10 DOWNING STREET, , LONDON, SW1A 2AA")

    expect(response).to eq(JSON.parse(File.read(File.join("spec", "fixtures", "sorting-office.json"))))
  end

  it "gives up and moves on after 5 retries" do
    stub_request(:post, "http://sorting-office.openaddressesuk.org/address").
      with(:body => "address=10%20DOWNING%20STREET%2C%20%2C%20LONDON%2C%20SW1A%202AA").
      to_return(status: 404, body: "")

    expect(Turbotlib).to receive(:log).with(/Address 10 DOWNING STREET, , LONDON, SW1A 2AA caused explosion/).at_least(5).times
    expect(Turbotlib).to receive(:log).with(/Retrying in 5 seconds./)
    expect(Turbotlib).to receive(:log).with(/Retrying in 10 seconds./)
    expect(Turbotlib).to receive(:log).with(/Retrying in 15 seconds./)
    expect(Turbotlib).to receive(:log).with(/Retrying in 20 seconds./)
    expect(Turbotlib).to receive(:log).with(/Retrying in 25 seconds./)
    expect(Turbotlib).to receive(:log).with(/Giving up/)
    allow(@companies_house).to receive(:sleep) { nil }

    response = @companies_house.request_with_retries("http://sorting-office.openaddressesuk.org/address", "10 DOWNING STREET, , LONDON, SW1A 2AA")

    expect(response).to eq(nil)
  end

  it "doesn't retry if the error is 400" do
    stub_request(:post, "http://sorting-office.openaddressesuk.org/address").
      with(:body => "address=10%20DOWNING%20STREET%2C%20%2C%20LONDON%2C%20SW1A%202AA").
      to_return(status: 400, body: "{\"error\": \"We couldn't detect a postcode in your address. Please resubmit with a valid postcode.\"}")

    expect(@companies_house).to_not receive(:sleep)

    @companies_house.request_with_retries("http://sorting-office.openaddressesuk.org/address", "10 DOWNING STREET, , LONDON, SW1A 2AA")
  end

end
