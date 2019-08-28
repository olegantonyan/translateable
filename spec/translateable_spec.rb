require 'spec_helper'

describe Translateable do
  before :all do
    I18n.available_locales = %i(en ru it)
    I18n.default_locale = :en
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
    I18n.locale = :en
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

  it 'replaces all locales data when hash is assigned' do
    I18n.locale = :en
    object = TestModel.create!(title: 'jumps over the lazy dog')
    object.title = { en: 'hello', ru: 'привет' }
    object.save!
    object.reload

    expect(object.title).to eq 'hello'
    I18n.with_locale(:ru) do
      expect(object.title).to eq 'привет'
    end
  end

  describe 'fallback locales' do
    it 'default locale if current locale does not exists' do
      I18n.locale = :en
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
        expect(object.title).to eq 'прыгает через' # fallback to first available locale
      end
      I18n.with_locale(:ru) do
        expect(object.title).to eq 'прыгает через'
      end
    end

    it 'should return nil if not the correct language using strict' do
      I18n.locale = :en
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
  end

  describe 'errors' do
    it 'raises an error when specified non-esistent attribute' do
      expect { TestModel.class_eval { translateable(:nonexist) } }.to raise_error(ArgumentError)
    end
  end

  describe 'methods' do
    it 'has translateable_attribute_by_name' do
      expect(Translateable.translateable_attribute_by_name(:title)).to eq 'title_translateable'
    end
  end

  describe 'raw hash access' do
    it 'allows to access raw JSONB value as hash' do
      I18n.config.available_locales = %i(en ru de it)

      I18n.locale = :en
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
end
