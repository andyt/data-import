require 'unit/spec_helper'

describe 'mappings' do
  let(:output_row) { {} }

  describe DataImport::Definition::Simple::NameMapping do
    describe "#apply!" do
      subject { described_class.new('sLegacyID', :id) }

      it '#apply! changes the column name form <old> to <new> when applied' do
        row = {:sLegacyID => 5}
        subject.apply!(nil, nil, row, output_row)
        output_row.should == {:id => 5}
      end

      it '#apply! does nothing when the mapped column is not present' do
        row = {:sOtherLegacyID => 5}
        subject.apply!(nil, nil, row, output_row)
        output_row.should == {}
      end
    end
  end

  describe DataImport::Definition::Simple::BlockMapping do
    let(:a_block) { lambda {} }
    describe "#apply!" do
      let(:context) { stub }
      let(:definition) { stub }

      context 'with a single column' do
        let(:a_block) {
          lambda { |context, legacy_id|
            {:id_times_two => legacy_id * 2}
          }
        }
        subject { described_class.new('sLegacyID', a_block) }

        it 'calls the block with the column value' do
          row = {:sLegacyID => 4}
          subject.apply!(definition, context, row, output_row)
          output_row.should == {:id_times_two => 8}
        end
      end

      context 'with multiple column' do
        let(:a_block) {
          lambda { |context, legacy_id, name|
            {:result => "#{name}#{legacy_id * 4}"}
          }
        }

        subject { described_class.new([:sLegacyID, :strLegacyName], a_block) }

        it 'calls the block with the column values' do
          row = {:sLegacyID => 3, :strLegacyName => 'Times four: '}
          subject.apply!(definition, context, row, output_row)
          output_row.should == {:result => 'Times four: 12'}
        end
      end

      context 'with an sterisk (*)' do
        subject { described_class.new('*', a_block) }
        let(:a_block) {
          lambda { |context, row|
            {:received_row => row}
          }
        }

        it 'passes the wole row to the block' do
          row = {:sLegacyID => 12, :strSomeName => 'John', :strSomeOtherString => 'Jane'}
          subject.apply!(definition, context, row, output_row)
          output_row.should == {:received_row => row}
        end
      end
    end
  end

  describe DataImport::Definition::Simple::WildcardBlockMapping do
    describe '#apply!' do
      let(:context) { stub }
      let(:definition) { stub }

      subject { described_class.new(a_block) }
      let(:a_block) {
        Proc.new {
          {:result => "#{arguments[:strSomeName]}#{arguments[:sLegacyID]}#{arguments[:strSomeOtherString]}"}
        }
      }

      it 'passes the wole row to the block' do
        row = {:sLegacyID => 12, :strSomeName => 'John', :strSomeOtherString => 'Jane'}

        context.should_receive(:arguments).any_number_of_times.and_return({:sLegacyID => 12, :strSomeName => 'John', :strSomeOtherString => 'Jane'})

        subject.apply!(definition, context, row, output_row)
        output_row.should == {:result => 'John12Jane'}
      end
    end
  end

  describe DataImport::Definition::Simple::ReferenceMapping do
    let(:context) { stub }
    let(:definition) { stub }

    context 'with a specific id lookup name' do
      subject { described_class.new('OldAddress', :sLegacyAddressId, :address_id, :reference) }

      it 'sets the foreign key to the newly generated primary key' do
        row = {:sLegacyAddressId => 28}

        address_definition = stub
        context.should_receive(:definition).with('OldAddress').and_return(address_definition)
        address_definition.should_receive(:identify_by).with(:reference, 28).and_return(4)

        subject.apply!(definition, context, row, output_row)
        output_row.should == {:address_id => 4}
      end
    end

    context 'with the default lookup name' do
      subject { described_class.new('OldAddress', :sLegacyAddressId, :address_id) }

      it 'uses :id to look up the newly generated id' do
        row = {:sLegacyAddressId => 28}

        address_definition = stub
        context.should_receive(:definition).with('OldAddress').and_return(address_definition)
        address_definition.should_receive(:identify_by).with(:id, 28)

        subject.apply!(definition, context, row, output_row)
      end
    end
  end

  describe DataImport::Definition::Simple::SeedMapping do
    let(:seed_hash) { {:my_name => 'John', :i_am => 'hungry'} }
    subject { DataImport::Definition::Simple::SeedMapping.new(seed_hash) }

    it "#apply! adds the passed seed-data" do
      subject.apply!(nil, nil, nil, output_row)
      output_row.should == seed_hash
    end
  end
end
