require 'spec_helper'
require 'open_food_network/products_renderer'

describe ProductsCacheIntegrityCheckerJob do
  describe "reporting on differences between the products cache and the current products" do
    let(:distributor) { create(:distributor_enterprise) }
    let(:order_cycle) { create(:simple_order_cycle) }
    let(:job) { ProductsCacheIntegrityCheckerJob.new distributor.id, order_cycle.id }
    let(:cache_key) { "products-json-#{distributor.id}-#{order_cycle.id}" }

    before do
      Rails.cache.write(cache_key, "[1, 2, 3]\n")
      allow(OpenFoodNetwork::ProductsRenderer).to receive(:new) { double(:pr, products_json: "[1, 3]\n") }
    end

    it "reports errors" do
      expect(Bugsnag).to receive(:notify)
      run_job job
    end

    it "deals with nil cached_json" do
      Rails.cache.delete(cache_key)
      expect(Bugsnag).to receive(:notify)
      run_job job
    end
  end
end
