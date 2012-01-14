module DataImport
  class Importer

    def initialize(context, definition, progress_reporter)
      @context = context
      @definition = definition
      @progress_reporter = progress_reporter
    end

    def run
      @definition.source_dataset.each_row do |row|
        import_row row
        @progress_reporter.inc
      end
      @definition.after_blocks.each do |block|
        @definition.instance_exec(@context, &block)
      end
    end

    def map_row(row)
      @definition.mappings.inject({}) do |mapped_row, mapping|
        mapped_row.merge(mapping.apply(@definition, @context, row))
      end
    end

    def import_row(row)
      mapped_row = map_row(row)
      case @definition.mode
      when :insert
        new_id = @definition.target_database.insert_row @definition.target_table_name, mapped_row
        @definition.row_imported(new_id, row)
      when :update
        @definition.target_database.update_row(@definition.target_table_name, mapped_row)
      end

      @definition.after_row_blocks.each do |block|
        @definition.instance_exec(@context, row, mapped_row, &block)
      end
    end
    private :import_row
  end
end
