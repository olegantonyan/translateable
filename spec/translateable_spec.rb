require 'spec_helper'

describe Translateable do
  def translateable_model(table = 'test_models', parent = ActiveRecord::Base, &block)
    Class.new(parent) do
      self.table_name = table
      include Translateable unless self < Translateable
      class_eval(&block) if block
    end
  end

  it 'has a version number' do
    expect(Translateable::VERSION).not_to be nil
  end

  it 'creates record with provided locale' do
    expect(TestModel.create!(title: 'hello').title).to eq 'hello'

    I18n.with_locale(:ru) do
      expect(TestModel.create!(title: 'привет').title).to eq 'привет'
    end

    I18n.with_locale(:it) do
      expect(TestModel.create!(title: 'ciao').title).to eq 'ciao'
    end
  end

  it 'adds new locales to existent records' do
    object = TestModel.create!(title: 'the quick brown fox')
    I18n.locale = :ru
    object.title = 'прыгает через ленивую собаку'
    object.save!
    object.reload

    expect(object.title).to eq 'прыгает через ленивую собаку'
    I18n.with_locale(:en) do
      expect(object.title).to eq 'the quick brown fox'
    end
  end

  it 'updates value for current locale only' do
    object = TestModel.create!(title: { en: 'hello', ru: 'привет' })
    object.update!(title: 'hi')
    object.reload

    expect(object[:title]).to eq('en' => 'hi', 'ru' => 'привет')
  end

  it 'keeps multiple attributes independent' do
    object = TestModel.create!(title: 'title', body: 'body')
    I18n.with_locale(:ru) { object.update!(body: 'тело') }
    object.reload

    expect(object[:title]).to eq('en' => 'title')
    expect(object[:body]).to eq('en' => 'body', 'ru' => 'тело')
  end

  describe 'hash assignment' do
    it 'replaces all locales data' do
      object = TestModel.create!(title: 'jumps over the lazy dog')
      object.title = { en: 'hello', ru: 'привет' }
      object.save!
      object.reload

      expect(object.title).to eq 'hello'
      I18n.with_locale(:ru) do
        expect(object.title).to eq 'привет'
      end
    end

    it 'accepts string keys' do
      object = TestModel.create!(title: { 'en' => 'hello', 'ru' => 'привет' })
      expect(object.reload[:title]).to eq('en' => 'hello', 'ru' => 'привет')
    end

    it 'accepts hash with indifferent access' do
      object = TestModel.create!(title: { en: 'hello' }.with_indifferent_access)
      expect(object.reload[:title]).to eq('en' => 'hello')
    end

    it 'accepts permitted controller parameters' do
      params = ActionController::Parameters.new(title: { en: 'hello', ru: 'привет' }).permit(title: %i(en ru))
      object = TestModel.new
      object.title = params[:title]
      object.save!
      expect(object.reload[:title]).to eq('en' => 'hello', 'ru' => 'привет')
    end
  end

  describe 'fallback locales' do
    it 'default locale if current locale does not exists' do
      object = TestModel.create!(title: 'hello world')
      I18n.with_locale('ru') do
        expect(object.title).to eq 'hello world'
      end
    end

    it 'to first available if default locale does not exists' do
      I18n.locale = :ru
      object = TestModel.create!(title: 'привет мир')
      I18n.with_locale('it') do
        expect(object.title).to eq 'привет мир'
      end
    end

    it 'nil otherwise' do
      I18n.locale = :ru
      object = TestModel.create!
      I18n.with_locale('it') do
        expect(object.title).to eq nil
      end
    end

    it 'nil for new record without translations' do
      expect(TestModel.new.title).to eq nil
      expect(TestModel.new.title(strict: true)).to eq nil
    end
  end

  describe 'strict' do
    it 'returns nil if there is no translation for current locale' do
      object = TestModel.create!(title: 'The Krankenwagen')
      I18n.with_locale('en') do
        expect(object.title(strict: true)).to eq 'The Krankenwagen'
      end
      I18n.with_locale('ru') do
        expect(object.title(strict: true)).to eq nil
      end
      I18n.with_locale('it') do
        expect(object.title).to eq 'The Krankenwagen'
      end
    end

    it 'does not fall back to first available locale' do
      object = TestModel.create!(title: { ru: 'привет' })
      expect(object.title(strict: true)).to eq nil
    end
  end

  describe 'nested attributes' do
    it 'is able to create' do
      object = TestModel.create!(title_translateable_attributes: { '0' => { locale: 'it', data: 'volpe veloce' } })
      I18n.with_locale(:it) do
        expect(object.title).to eq 'volpe veloce'
      end
    end

    it 'is able to update' do
      object = TestModel.create!(title_translateable_attributes: { '0' => { locale: 'it', data: 'volpe veloce' } })
      object.update(title_translateable_attributes: { '0' => { locale: 'it', data: 'salti sopra' } })
      I18n.with_locale(:it) do
        expect(object.title).to eq 'salti sopra'
      end
    end

    it 'is able to update and add new' do
      object = TestModel.create!(title_translateable_attributes: { '0' => { locale: 'it', data: 'volpe veloce' } })
      object.update(title_translateable_attributes: { '0' => { locale: 'it', data: 'salti sopra' }, '1' => { locale: :ru, data: 'прыгает через' } })
      I18n.with_locale(:it) do
        expect(object.title).to eq 'salti sopra'
      end
      I18n.with_locale(:ru) do
        expect(object.title).to eq 'прыгает через'
      end
    end

    it 'is able to destroy' do
      object = TestModel.create!(title_translateable_attributes: { '0' => { locale: 'it', data: 'salti sopra' }, '1' => { locale: :ru, data: 'прыгает через' } })
      object.update(title_translateable_attributes: { '0' => { locale: 'it', data: 'salti sopra', _destroy: 1 }, '1' => { locale: :ru, data: 'прыгает через' } })
      I18n.with_locale(:it) do
        expect(object.title).to eq 'прыгает через'
      end
      I18n.with_locale(:ru) do
        expect(object.title).to eq 'прыгает через'
      end
    end

    it 'accepts string keys' do
      object = TestModel.create!(title_translateable_attributes: { '0' => { 'locale' => 'it', 'data' => 'volpe veloce' } })
      expect(object.reload[:title]).to eq('it' => 'volpe veloce')
    end

    it 'treats symbol and string locales as the same' do
      object = TestModel.create!(title_translateable_attributes: { '0' => { locale: :it, data: 'volpe' }, '1' => { locale: 'it', data: 'volpe veloce' } })
      expect(object.reload[:title]).to eq('it' => 'volpe veloce')
    end

    it 'accepts array of hashes' do
      object = TestModel.create!(title_translateable_attributes: [{ locale: 'it', data: 'volpe' }, { locale: 'ru', data: 'лиса' }])
      expect(object.reload[:title]).to eq('it' => 'volpe', 'ru' => 'лиса')
    end

    ['0', 'false', '', false, nil].each do |flag|
      it "keeps translation when _destroy is #{flag.inspect}" do
        object = TestModel.create!(title_translateable_attributes: { '0' => { locale: 'it', data: 'volpe', _destroy: flag } })
        expect(object.reload[:title]).to eq('it' => 'volpe')
      end
    end

    ['1', 'true', true, 1].each do |flag|
      it "removes translation when _destroy is #{flag.inspect}" do
        object = TestModel.create!(title_translateable_attributes: { '0' => { locale: 'it', data: 'volpe', _destroy: flag }, '1' => { locale: 'ru', data: 'лиса' } })
        expect(object.reload[:title]).to eq('ru' => 'лиса')
      end
    end

    it 'accepts permitted controller parameters' do
      params = ActionController::Parameters.new(
        title_translateable_attributes: {
          '0' => { locale: 'en', data: 'hello', _destroy: '' },
          '1' => { locale: 'ru', data: 'привет', _destroy: '0' },
          '2' => { locale: 'it', data: 'ciao', _destroy: '1' }
        }
      ).permit(*TestModel.translateable_permitted_attributes)

      object = TestModel.create!(params)
      expect(object.reload[:title]).to eq('en' => 'hello', 'ru' => 'привет')
    end
  end

  describe 'permitted attributes' do
    it 'includes all attributes' do
      expect(TestModel.translateable_permitted_attributes).to eq [
        { 'title_translateable_attributes' => %i(locale data _destroy) },
        { 'body_translateable_attributes' => %i(locale data _destroy) }
      ]
    end

    it 'accumulates attributes from multiple macro calls' do
      model = translateable_model do
        translateable :title
        translateable :body
      end

      expect(model.translateable_permitted_attributes.map(&:keys).flatten).to eq %w(title_translateable_attributes body_translateable_attributes)
    end

    it 'inherits attributes from parent class without leaking back' do
      parent = translateable_model { translateable :title }
      child = translateable_model('test_models', parent) { translateable :body }

      expect(parent.translateable_permitted_attributes.map(&:keys).flatten).to eq %w(title_translateable_attributes)
      expect(child.translateable_permitted_attributes.map(&:keys).flatten).to eq %w(title_translateable_attributes body_translateable_attributes)
    end
  end

  describe 'sanity checks' do
    it 'raises an error when specified non-existent attribute' do
      expect { translateable_model { translateable(:nonexist) } }.to raise_error(ArgumentError, /nonexist/)
    end

    it 'can be disabled with an option' do
      expect { translateable_model { translateable(:nonexist, sanity_checks: false) } }.not_to raise_error
    end

    it 'can be disabled with an environment variable' do
      ENV['DISABLE_TRANSLATEABLE_SANITY_CHECK'] = 'true'
      expect { translateable_model { translateable(:nonexist) } }.not_to raise_error
    ensure
      ENV.delete('DISABLE_TRANSLATEABLE_SANITY_CHECK')
    end

    it 'skips check when table does not exist yet' do
      model = nil
      expect { model = translateable_model('late_models') { translateable(:title) } }.not_to raise_error

      ActiveRecord::Base.connection.create_table(:late_models) { |t| t.jsonb :title }
      model.reset_column_information
      expect(model.create!(title: 'hello').reload.title).to eq 'hello'
    ensure
      ActiveRecord::Base.connection.drop_table(:late_models, if_exists: true)
    end
  end

  describe 'methods' do
    it 'has translateable_attribute_by_name' do
      expect(Translateable.translateable_attribute_by_name(:title)).to eq 'title_translateable'
    end
  end

  describe 'raw hash access' do
    it 'allows to access raw JSONB value as hash' do
      object = TestModel.create!(title: 'Hello World')
      I18n.locale = :de
      object.title = 'Hallo Welt'

      %i(en ru de it).each do |locale|
        I18n.with_locale(locale) do
          expect(object[:title]).to eq('en' => 'Hello World', 'de' => 'Hallo Welt')
        end
      end
    end
  end

  describe 'attribute value object' do
    it 'returns array of objects with translations' do
      object = TestModel.create!(title: 'Hello World')
      I18n.locale = :ru
      object.update!(title: 'Привет мир')

      expect(object.title_translateable.size).to eq(2)
      expect(object.title_translateable.first.locale).to eq('en')
      expect(object.title_translateable.first.data).to eq('Hello World')
      expect(object.title_translateable.last.locale).to eq('ru')
      expect(object.title_translateable.last.data).to eq('Привет мир')
    end

    it 'returns a blank translation for current locale on new record' do
      I18n.with_locale(:ru) do
        expect(TestModel.new.title_translateable.map(&:to_h)).to eq [{ locale: 'ru', data: '' }]
      end
    end

    it 'returns no translations for persisted record without data' do
      expect(TestModel.create!.title_translateable).to eq []
    end

    it 'can be built without arguments' do
      value = Translateable::AttributeValue.new
      expect([value.locale, value.data, value._destroy, value.persisted?]).to eq [nil, nil, nil, false]
    end

    it 'renders in nested form fields' do
      object = TestModel.create!(title: { en: 'hello', ru: 'привет' })
      html = ActionView::Base.empty.fields_for(:test_model, object) do |f|
        f.fields_for(Translateable.translateable_attribute_by_name(:title)) do |ff|
          ff.text_field(:data) + ff.hidden_field(:_destroy)
        end
      end

      expect(html).to include('name="test_model[title_translateable_attributes][0][data]"', 'value="hello"')
      expect(html).to include('name="test_model[title_translateable_attributes][1][data]"', 'value="привет"')
    end
  end

  describe 'plain form fields' do
    def render_fields(object)
      ActionView::Base.empty.fields_for(:test_model, object) do |f|
        f.text_field(:title) + f.text_area(:body)
      end
    end

    it 'show the current locale for a loaded record' do
      object = TestModel.find(TestModel.create!(title: { en: 'hello', ru: 'привет' }).id)
      html = I18n.with_locale(:ru) { render_fields(object) }

      expect(html).to include('value="привет"')
    end

    it 'show the assigned text when re-rendered after a failed validation' do
      object = TestModel.new(title: 'hello', body: 'world')
      html = render_fields(object)

      expect(html).to include('value="hello"', ">\nworld</textarea>")
      expect(html).not_to include('&quot;en&quot;')
    end

    it 'show the text assigned for the current locale among others' do
      object = TestModel.create!(title: 'hello')
      html = I18n.with_locale(:de) do
        object.title = 'hallo'
        render_fields(object)
      end

      expect(html).to include('value="hallo"')
      expect(object[:title]).to eq('en' => 'hello', 'de' => 'hallo')
    end

    it 'leave before_type_cast of non-translateable attributes alone' do
      expect(TestModel.new(id: '42').id_before_type_cast).to eq '42'
    end
  end
end
