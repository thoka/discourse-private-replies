import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class PrivateRepliesUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  @service siteSettings;

  @tracked privateRepliesEnabled = false;
  @tracked privateRepliesDefaultEnabled = false;

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  get categoryPrivateRepliesEnabled() {
    return (
      this.siteSettings.private_replies_on_selected_categories_only === false ||
      this.privateRepliesEnabled
    );
  }

  constructor() {
    super(...arguments);

    this.privateRepliesEnabled =
      this.customFields?.private_replies_enabled?.toString() === "true";
    this.privateRepliesDefaultEnabled =
      this.customFields?.private_replies_default_enabled?.toString() === "true";

    if (this.customFields) {
      this.customFields.private_replies_enabled = this.privateRepliesEnabled;
      this.customFields.private_replies_default_enabled =
        this.privateRepliesDefaultEnabled;
    }
  }

  @action
  async onTogglePrivateRepliesEnabled(_, { set: formSet, name }) {
    const enabled = !this.privateRepliesEnabled;

    this.privateRepliesEnabled = enabled;
    this.customFields.private_replies_enabled = enabled;

    await formSet(name, enabled);
  }

  @action
  async onTogglePrivateRepliesDefaultEnabled(_, { set: formSet, name }) {
    const enabled = !this.privateRepliesDefaultEnabled;

    this.privateRepliesDefaultEnabled = enabled;
    this.customFields.private_replies_default_enabled = enabled;

    await formSet(name, enabled);
  }

  <template>
    {{#if this.siteSettings.private_replies_enabled}}
      {{#let @outletArgs.form as |form|}}
        <form.Section
          @title={{i18n "private_replies.title"}}
          class="category-custom-settings-outlet private-replies"
        >
          <form.Object @name="custom_fields" as |customFields|>
            {{#if this.siteSettings.private_replies_on_selected_categories_only}}
              <customFields.Field
                @name="private_replies_enabled"
                @title={{i18n "private_replies.private_replies_enabled"}}
                @onSet={{this.onTogglePrivateRepliesEnabled}}
                @type="checkbox"
                as |field|
              >
                <field.Control checked={{this.privateRepliesEnabled}} />
              </customFields.Field>
            {{/if}}

            {{#if this.categoryPrivateRepliesEnabled}}
              <customFields.Field
                @name="private_replies_default_enabled"
                @title={{i18n "private_replies.category_default_enabled"}}
                @onSet={{this.onTogglePrivateRepliesDefaultEnabled}}
                @type="checkbox"
                as |field|
              >
                <field.Control checked={{this.privateRepliesDefaultEnabled}} />
              </customFields.Field>
              <p class="form-kit-text form-kit__container-subtitle">{{i18n "private_replies.category_default_subtext"}}</p>
            {{/if}}
          </form.Object>
        </form.Section>
      {{/let}}
    {{/if}}
  </template>
}