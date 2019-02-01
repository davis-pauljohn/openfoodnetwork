require "spec_helper"

feature "enterprise fee summaries" do
  include AuthenticationWorkflow
  include WebHelper

  let!(:distributor) { create(:distributor_enterprise) }
  let!(:other_distributor) { create(:distributor_enterprise) }

  let!(:order_cycle) { create(:simple_order_cycle, coordinator: distributor) }
  let!(:other_order_cycle) { create(:simple_order_cycle, coordinator: other_distributor) }

  before do
    feature_flags = instance_double(FeatureFlags, enterprise_fee_summary_enabled?: true)
    allow(FeatureFlags).to receive(:new).with(current_user) { feature_flags }

    login_as current_user
  end

  describe "navigation" do
    context "when accessing the report as an superadmin" do
      let(:current_user) { create(:admin_user) }

      it "shows link and allows access to the report" do
        visit spree.admin_reports_path
        click_on I18n.t("admin.reports.enterprise_fee_summary.name")
        expect(page).to have_button(I18n.t("filters.generate_report", scope: i18n_scope))
      end
    end

    context "when accessing the report as an admin" do
      let(:current_user) { distributor.owner }

      it "shows link and allows access to the report" do
        visit spree.admin_reports_path
        click_on I18n.t("admin.reports.enterprise_fee_summary.name")
        expect(page).to have_button(I18n.t("filters.generate_report", scope: i18n_scope))
      end

      context "when feature flag is in effect" do
        before { allow(FeatureFlags).to receive(:new).with(current_user).and_call_original }

        it "does not show link now allow direct access to the report" do
          visit spree.admin_reports_path
          expect(page).to have_no_link I18n.t("admin.reports.enterprise_fee_summary.name")
          visit spree.new_admin_reports_enterprise_fee_summary_path
          expect(page).to have_no_button(I18n.t("filters.generate_report", scope: i18n_scope))
        end
      end
    end

    context "when accessing the report as an enterprise user without sufficient permissions" do
      let(:current_user) { create(:user) }

      it "does not allow access to the report" do
        visit spree.admin_reports_path
        expect(page).to have_no_link(I18n.t("admin.reports.enterprise_fee_summary.name"))
        visit spree.new_admin_reports_enterprise_fee_summary_path
        expect(page).to have_content(I18n.t("unauthorized"))
      end

      context "when feature flag is in effect" do
        before { allow(FeatureFlags).to receive(:new).with(current_user).and_call_original }

        it "does not show link now allow direct access to the report" do
          visit spree.admin_reports_path
          expect(page).to have_no_link I18n.t("admin.reports.enterprise_fee_summary.name")
          visit spree.new_admin_reports_enterprise_fee_summary_path
          expect(page).to have_no_button(I18n.t("filters.generate_report", scope: i18n_scope))
        end
      end
    end
  end

  describe "smoke test for filters" do
    before do
      visit spree.new_admin_reports_enterprise_fee_summary_path
    end

    context "when logged in as admin" do
      let(:current_user) { create(:admin_user) }

      it "shows all available options" do
        expect(page).to have_select "report_order_cycle_ids", with_options: [order_cycle.name]
      end
    end

    context "when logged in as enterprise user" do
      let!(:order) { create(:completed_order_with_fees, order_cycle: order_cycle, distributor: distributor) }

      let(:current_user) { distributor.owner }

      it "shows available options for the enterprise" do
        expect(page).to have_select "report_order_cycle_ids", options: [order_cycle.name]
      end
    end
  end

  describe "smoke test for generation of report based on permissions" do
    before do
      visit spree.new_admin_reports_enterprise_fee_summary_path
    end

    context "when logged in as admin" do
      let!(:order) { create(:completed_order_with_fees, order_cycle: order_cycle, distributor: distributor) }

      let(:current_user) { create(:admin_user) }

      it "generates file with data for all enterprises" do
        check I18n.t("filters.report_format_csv", scope: i18n_scope)
        click_on I18n.t("filters.generate_report", scope: i18n_scope)
        expect(page.response_headers['Content-Type']).to eq "text/csv"
        expect(page.body).to have_content(distributor.name)
      end
    end

    context "when logged in as enterprise user" do
      let!(:order) { create(:completed_order_with_fees, order_cycle: order_cycle, distributor: distributor) }
      let!(:other_order) { create(:completed_order_with_fees, order_cycle: other_order_cycle, distributor: other_distributor) }

      let(:current_user) { distributor.owner }

      it "generates file with data for the enterprise" do
        check I18n.t("filters.report_format_csv", scope: i18n_scope)
        click_on I18n.t("filters.generate_report", scope: i18n_scope)
        expect(page.response_headers['Content-Type']).to eq "text/csv"
        expect(page.body).to have_content(distributor.name)
        expect(page.body).not_to have_content(other_distributor.name)
      end
    end
  end

  describe "smoke test for filtering report based on filters" do
    let!(:second_distributor) { create(:distributor_enterprise) }
    let!(:second_order_cycle) { create(:simple_order_cycle, coordinator: second_distributor) }

    let!(:order) { create(:completed_order_with_fees, order_cycle: order_cycle, distributor: distributor) }
    let!(:second_order) { create(:completed_order_with_fees, order_cycle: second_order_cycle, distributor: second_distributor) }

    let(:current_user) { create(:admin_user) }

    before do
      visit spree.new_admin_reports_enterprise_fee_summary_path
    end

    it "generates file with data for selected order cycle" do
      select order_cycle.name, from: "report_order_cycle_ids"
      check I18n.t("filters.report_format_csv", scope: i18n_scope)
      click_on I18n.t("filters.generate_report", scope: i18n_scope)
      expect(page.response_headers['Content-Type']).to eq "text/csv"
      expect(page.body).to have_content(distributor.name)
      expect(page.body).not_to have_content(second_distributor.name)
    end
  end

  def i18n_scope
    "spree.admin.reports.enterprise_fee_summaries"
  end
end
