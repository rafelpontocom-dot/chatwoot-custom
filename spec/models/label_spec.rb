require 'rails_helper'

RSpec.describe Label do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'visibility' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }

    it 'defaults to global, so a label created without a stated visibility stays visible to everyone' do
      expect(create(:label, account: account).visibility).to eq('global')
    end

    # Uma etiqueta pessoal sem autor é uma etiqueta que ninguém consegue ver.
    it 'refuses a personal label without an author' do
      label = build(:label, account: account, visibility: :personal, created_by: nil)

      expect(label).not_to be_valid
      expect(label.errors[:created_by]).to be_present
    end

    it 'refuses a team label without a team' do
      label = build(:label, account: account, visibility: :team, team: nil)

      expect(label).not_to be_valid
      expect(label.errors[:team]).to be_present
    end

    it 'refuses a team from another account' do
      label = build(:label, account: account, visibility: :team, team: create(:team))

      expect(label).not_to be_valid
    end

    describe '.visible_to' do
      it 'returns the global ones, the user own personal ones and the ones of their teams' do
        team = create(:team, account: account)
        create(:team_member, team: team, user: user)
        global = create(:label, account: account, title: 'de-todos')
        mine = create(:label, account: account, title: 'minha', visibility: :personal, created_by: user)
        team_label = create(:label, account: account, title: 'do-time', visibility: :team, team: team)
        other = create(:label, account: account, title: 'de-outro', visibility: :personal, created_by: create(:user, account: account))
        other_team = create(:label, account: account, title: 'de-outro-time', visibility: :team, team: create(:team, account: account))

        visiveis = account.labels.visible_to(user)

        expect(visiveis).to include(global, mine, team_label)
        expect(visiveis).not_to include(other, other_team)
      end

      it 'shows no team label to a user without teams' do
        team_label = create(:label, account: account, title: 'do-time', visibility: :team, team: create(:team, account: account))

        expect(account.labels.visible_to(user)).not_to include(team_label)
      end
    end
  end

  describe 'title validations' do
    it 'would not let you start title without numbers or letters' do
      label = FactoryBot.build(:label, title: '_12')
      expect(label.valid?).to be false
    end

    it 'would not let you use special characters' do
      label = FactoryBot.build(:label, title: 'jell;;2_12')
      expect(label.valid?).to be false
    end

    it 'would not allow space' do
      label = FactoryBot.build(:label, title: 'heeloo _12')
      expect(label.valid?).to be false
    end

    it 'allows foreign charactes' do
      label = FactoryBot.build(:label, title: '学中文_12')
      expect(label.valid?).to be true
    end

    it 'would not let you use a title with a trailing newline' do
      # Regression test: the format validator used to anchor on \Z instead of \z, and \Z tolerates
      # a single trailing newline, so 'hello_world' + "\n" incorrectly passed validation.
      label = FactoryBot.build(:label, title: "hello_world\n")
      expect(label.valid?).to be false
    end

    it 'converts uppercase letters to lowercase' do
      label = FactoryBot.build(:label, title: 'Hello_World')
      expect(label.valid?).to be true
      expect(label.title).to eq 'hello_world'
    end

    it 'validates uniqueness of label name for account' do
      account = create(:account)
      label = FactoryBot.create(:label, account: account)
      duplicate_label = FactoryBot.build(:label, title: label.title, account: account)
      expect(duplicate_label.valid?).to be false
    end
  end

  describe '.after_update_commit' do
    let(:label) { create(:label) }

    it 'calls update job' do
      expect(Labels::UpdateJob).to receive(:perform_later).with('new-title', label.title, label.account_id)

      label.update(title: 'new-title')
    end

    it 'does not call update job if title is not updated' do
      expect(Labels::UpdateJob).not_to receive(:perform_later)

      label.update(description: 'new-description')
    end
  end
end
