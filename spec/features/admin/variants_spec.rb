require 'spec_helper'

feature '
    As an admin
    I want to manage product variants
' do
  include AuthenticationWorkflow
  include WebHelper

  scenario "creating a new variant" do
    # Given a product with a unit-related option type
    p = create(:simple_product, variant_unit: "weight", variant_unit_scale: "1")

    # When I create a variant on the product
    login_to_admin_section
    visit spree.admin_product_variants_path p
    click_link 'New Variant'

    fill_in 'unit_value_human', with: '1'
    fill_in 'variant_unit_description', with: 'foo'
    click_button 'Create'

    # Then the variant should have been created
    expect(page).to have_content "Variant \"#{p.name}\" has been successfully created!"
  end

  scenario "editing unit value and description for a variant", js: true do
    # Given a product with unit-related option types, with a variant
    p = create(:simple_product, variant_unit: "weight", variant_unit_scale: "1")
    v = p.variants.first
    v.update_attributes( unit_value: 1, unit_description: 'foo' )

    # And the product has option types for the unit-related and non-unit-related option values
    p.option_types << v.option_values.first.option_type

    # When I view the variant
    login_to_admin_section
    visit spree.admin_product_variants_path p
    page.find('table.index .icon-edit').click

    # Then I should not see a traditional option value field for the unit-related option value
    expect(page).to have_no_selector "div[data-hook='presentation'] input"

    # And I should see unit value and description fields for the unit-related option value
    expect(page).to have_field "unit_value_human", with: "1"
    expect(page).to have_field "variant_unit_description", with: "foo"

    # When I update the fields and save the variant
    fill_in "unit_value_human", with: "123"
    fill_in "variant_unit_description", with: "bar"
    click_button 'Update'
    expect(page).to have_content %(Variant "#{p.name}" has been successfully updated!)

    # Then the unit value and description should have been saved
    v.reload
    expect(v.unit_value).to eq(123)
    expect(v.unit_description).to eq('bar')
  end

  describe "editing on hand and on demand values", js: true do
    let(:product) { create(:simple_product) }
    let(:variant) { product.variants.first }

    before do
      login_to_admin_section
    end

    it "allows changing the on_hand value" do
      visit spree.edit_admin_product_variant_path(product, variant)

      expect(page).to have_field "variant_on_hand", with: variant.on_hand
      expect(page).to have_unchecked_field "variant_on_demand"

      fill_in "variant_on_hand", with: "123"
      click_button 'Update'
      expect(page).to have_content %(Variant "#{product.name}" has been successfully updated!)
    end

    it "allows changing the on_demand value" do
      visit spree.edit_admin_product_variant_path(product, variant)
      check "variant_on_demand"

      # on_hand reflects the change in on_demand
      expect(page).to have_field "variant_on_hand", with: "Infinity", disabled: true

      click_button 'Update'
      expect(page).to have_content %(Variant "#{product.name}" has been successfully updated!)
    end

    it "memorizes on_hand value previously entered if enabling and disabling on_demand" do
      visit spree.edit_admin_product_variant_path(product, variant)
      fill_in "variant_on_hand", with: "123"
      check "variant_on_demand"
      uncheck "variant_on_demand"

      # on_hand shows the memorized value, not the original DB value
      expect(page).to have_field "variant_on_hand", with: "123"
    end
  end

  it "soft-deletes variants", js: true do
    p = create(:simple_product)
    v = create(:variant, product: p)

    login_to_admin_section
    visit spree.admin_product_variants_path p

    within "tr#spree_variant_#{v.id}" do
      accept_alert do
        page.find('a.delete-resource').click
      end
    end

    expect(page).not_to have_selector "tr#spree_variant_#{v.id}"

    v.reload
    expect(v.deleted_at).not_to be_nil
  end

  scenario "editing display name for a variant", js: true do
    p = create(:simple_product)
    v = p.variants.first

    # When I view the variant
    login_to_admin_section
    visit spree.admin_product_variants_path p
    page.find('table.index .icon-edit').click

    # It should allow the display name to be changed
    expect(page).to have_field "variant_display_name"
    expect(page).to have_field "variant_display_as"

    # When I update the fields and save the variant
    fill_in "variant_display_name", with: "Display Name"
    fill_in "variant_display_as", with: "Display As This"
    click_button 'Update'
    expect(page).to have_content %(Variant "#{p.name}" has been successfully updated!)

    # Then the displayed values should have been saved
    v.reload
    expect(v.display_name).to eq("Display Name")
    expect(v.display_as).to eq("Display As This")
  end
end
