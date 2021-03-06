module Spree
  module Admin
    PaymentMethodsController.class_eval do
      before_filter :restrict_stripe_account_change, only: [:update]
      before_filter :force_environment, only: [:create, :update]
      skip_before_filter :load_resource, only: [:show_provider_preferences]
      before_filter :load_hubs, only: [:new, :edit, :update]
      create.before :load_hubs

      # Only show payment methods that user has access to and sort by distributor name
      # ! Redundant code copied from Spree::Admin::ResourceController with modifications marked
      def collection
        return parent.public_send(controller_name) if parent_data.present?
        collection = if model_class.respond_to?(:accessible_by) &&
                        !current_ability.has_block?(params[:action], model_class)

                       model_class.accessible_by(current_ability, action)

                     else
                       model_class.scoped
                     end

        collection = collection.managed_by(spree_current_user).by_name # This line added

        # This block added
        if params.key? :enterprise_id
          distributor = Enterprise.find params[:enterprise_id]
          collection = collection.for_distributor(distributor)
        end

        collection
      end

      def show_provider_preferences
        if params[:pm_id].present?
          @payment_method = PaymentMethod.find(params[:pm_id])
          authorize! :show_provider_preferences, @payment_method
          payment_method_type = params[:provider_type]
          if @payment_method['type'].to_s != payment_method_type
            @payment_method.update_column(:type, payment_method_type)
            @payment_method = PaymentMethod.find(params[:pm_id])
          end
        else
          @payment_method = params[:provider_type].constantize.new
        end
        render partial: 'provider_settings'
      end

      private

      def force_environment
        params[:payment_method][:environment] = Rails.env unless spree_current_user.admin?
      end

      def load_data
        @providers = if spree_current_user.admin? || Rails.env.test?
                       Gateway.providers.sort_by(&:name)
                     else
                       Gateway.providers.reject{ |p| p.name.include? "Bogus" }.sort_by(&:name)
                     end
        @providers.reject!{ |p| p.name.ends_with? "StripeConnect" } unless show_stripe?
        @calculators = PaymentMethod.calculators.sort_by(&:name)
      end

      def load_hubs
        # rubocop:disable Style/TernaryParentheses
        @hubs = Enterprise.managed_by(spree_current_user).is_distributor.sort_by! do |d|
          [(@payment_method.has_distributor? d) ? 0 : 1, d.name]
        end
        # rubocop:enable Style/TernaryParentheses
      end

      # Show Stripe as an option if enabled, or if the
      # current payment_method is already a Stripe method
      def show_stripe?
        Spree::Config.stripe_connect_enabled || @payment_method.try(:type) == "Spree::Gateway::StripeConnect"
      end

      def restrict_stripe_account_change
        return unless @payment_method
        return unless @payment_method.type == "Spree::Gateway::StripeConnect"
        return unless @payment_method.preferred_enterprise_id.andand > 0

        @stripe_account_holder = Enterprise.find(@payment_method.preferred_enterprise_id)
        return if spree_current_user.enterprises.include? @stripe_account_holder

        params[:payment_method][:preferred_enterprise_id] = @stripe_account_holder.id
      end
    end
  end
end
