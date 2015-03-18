require 'spec_helper'

describe CompaniesHouse do

  before(:each) do
    @companies_house = CompaniesHouse.new("test-file.csv")
  end

  it "parses an address from a CSV row correctly" do
    stub_request(:post, "http://sorting-office.openaddressesuk.org/address").
      with(:body => "address=10%20DOWNING%20STREET%2C%20%2C%20LONDON%2C%20SW1A%202AA").
      to_return(body: File.open(File.join("spec", "fixtures", "sorting-office.json")))

      allow(@companies_house).to receive(:build_provenance) { nil }

    row = {
      "RegAddress.AddressLine1" => "10 DOWNING STREET",
      "RegAddress.AddressLine2" => "",
      "RegAddress.PostTown" => "LONDON",
      "RegAddress.County" => "",
      "RegAddress.Country" => "",
      "RegAddress.PostCode" => "SW1A 2AA"
    }

    expected = {
      saon: nil,
      paon: "10",
      street: "Downing Street",
      locality: nil,
      town: "London",
      postcode: "SW1A 2AA",
      provenance: nil
    }.to_json

    expect { @companies_house.parse_address(row) }.to output(expected + "\n").to_stdout
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

end
