begin

  require 'ncurses'
  require 'rbcurse'

  require 'rbcurse/rtable'
  require 'rbcurse/rsplitpane'
  require 'rbcurse/rtextview'

  include RubyCurses

  class Executable
    def run_command(task, command)
      require 'open3'
      stdin, stdout, stderr = Open3.popen3(command)
      puts "StdOut:"
      puts stdout.readlines
      puts "StdErr:"
      puts stderr.readlines
    end
  end

  class RakeGui
    def initialize
      Cxxproject::ColorizingFormatter.enabled = false
      Rake::Task.output_disabled = true

      $log = Logger.new(File.join("./", "view.log"))
      $log.level = Logger::ERROR
      @data_stack = []
      @path_stack = []
    end

    def self.keycode(s)
      return s[0].to_i
    end

    def create_table
      rake_gui = self
      @col_names = ['name', 'desc']
      res = Table.new nil do
        name 'my table'
        title 'my table'
        cell_editing_allowed false
      end

      res.configure do
        bind_key(RakeGui.keycode('r')) do
          rake_gui.invoke(self)
        end
        bind_key(RakeGui.keycode('d')) do
          rake_gui.details(self)
        end
        [RakeGui.keycode('p'), KEY_BACKSPACE].each do |code|
          bind_key(code) do
            rake_gui.pop_data
          end
        end
      end

      return res
    end

    def invoke(table)
      t = table.get_value_at(table.focussed_row, 0)
      begin
        $log.error "root task #{t} -> #{t.class}"
        @progress_helper = ProgressHelper.new
        @progress_helper.count(t)
        $log.error @progress_helper.todo

        @progress.max = @progress_helper.todo
        require 'cxxproject/extensions/rake_listener_ext'
        Rake::add_listener(self)
        t.failure = false
        t.reenable
        t.invoke
        Rake::remove_listener(self)
      rescue => e
        $log.error e
      end
      $log.error "#{t.name} #{t.failure}"
    end
    def before_prerequisites(name)
    end
    def after_prerequisites(name)
    end
    def before_execute(name)
    end
    def after_execute(name)
      needed_tasks = @progress_helper.needed_tasks
      if needed_tasks[name]
        task = Rake::Task[name]
        @progress.title = task.name
        @progress.inc(task.progress_count)
      end
    end

    def details(table)
      t = table.get_value_at(table.focussed_row, 0)
      pre = t.prerequisite_tasks
      if pre.size > 0
        push_table_data(pre, t.name)
        table.set_focus_on 0

        show_details_for(0)
      end
    end

    def process_input_events
      ch = @window.getchar
      while ch != RakeGui.keycode('q')
        $log.error "entered key: #{ch}"
        case ch
          when RakeGui.keycode('a')
            @h_split.set_divider_location(@h_split.divider_location+1)
          when RakeGui.keycode('s')
            @h_split.set_divider_location(@h_split.divider_location-1)
          else
            @form.handle_key(ch)
        end

        @form.repaint
        @window.wrefresh
        ch = @window.getchar
      end
    end

    def push_table_data(task_data, new_path=nil)
      @path_stack.push(new_path) if new_path
      set_breadcrumbs

      @data_stack.push(task_data)
      set_table_data(task_data)
    end
    def set_table_data(task_data)
      size = size()
      new_data = task_data.map{|t|[t, t.comment]}
      @table.set_data new_data, @col_names
      tcm = @table.table_column_model
      first_col_width = task_data.map{|t|t.name.size}.max
      tcm.column(0).width(first_col_width)
      tcm.column(1).width(size[0]-first_col_width-3)
    end
    def set_breadcrumbs
      crumbs = File.join(@path_stack.map{|i|"(#{i})"}.join('/'))
      @breadcrumbs.text = crumbs
      @breadcrumbs.repaint_all(true)
    end
    def pop_data
      if @data_stack.size > 1
        @path_stack.pop
        set_breadcrumbs

        popped = @data_stack.pop
        top= @data_stack.last
        set_table_data(top)
      end
    end

    def size
      return @window.default_for(:width), @window.default_for(:height)
    end

    def show_details_for(row)
      t = @table.get_value_at(row, 0)
      @output.set_content(t.output_string || '')
      @output.set_focus_on(0)
      @output.repaint_all(true)
    end
    def start_editor(file, line, column)
      $log.error "starting editor for #{file}:#{line}"
      cmd = "emacsclient +#{line}:#{column} #{file}"
      require 'open3'

      stdin, stdout, stderr = Open3.popen3(cmd)
      $log.error(stdout.readlines)
      $log.error(stderr.readlines)
    end

    class Progress
      def initialize(form, size)
        @form = form
        @width = size[0]
        $log.error size
        @progress = Label.new form do
          name 'progress'
          row size[1]-1
          col 0
          width size[0]
          height 1
        end
        @progress.display_length(@width)
        @progress.text = '-'*@width
        max = 100
      end

      def title=(t)
        $log.error "worked on #{t}"
      end

      def inc(i)
        @current += i
        total = (@current.to_f / @max.to_f * @width.to_f).to_i
        text = "#" * total
        $log.error "setting progress #{total}"
        @progress.text = text

        @form.repaint
      end

      def max=(f)
        @max = f.to_f
        @current = 0.0
        @progress.text = "max set to #{@max}"
      end
    end

    def run
      rake_gui = self
      begin
        VER::start_ncurses

        @window = VER::Window.root_window
        catch (:close) do
          @form = Form.new @window
          size = size()
          @breadcrumbs = Label.new @form do
            name 'breadcrumbs'
            row 0
            col 0
            width size[0]
            height 1
          end
          @breadcrumbs.display_length(size[0])
          @breadcrumbs.text = ''

          @progress = Progress.new(@form, size)

          @h_split = SplitPane.new @form do
            name 'mainpane'
            row 1
            col 0
            width size[0]
            height size[1]-2
            orientation :HORIZONTAL_SPLIT
          end
          @table = create_table
          push_table_data(Rake::Task.tasks.select {|t|t.comment})

          @output = TextView.new nil
          @output.set_content('')
          @output.configure do
            bind_key(RakeGui.keycode('e')) do |code|
              line = selected_item
              $log.error "current line #{line}"
              file_pattern = '(.*?):(\d+):(\d*):? '
              error_pattern = Regexp.new("#{file_pattern}(error: .*)")
              warning_pattern = Regexp.new("#{file_pattern}(warning: .*)")
              md = error_pattern.match(line)
              md = warning_pattern.match(line) unless md
              $log.error "MatchData #{md}"
              if md
                file_name = md[1]
                line = md[2]
                col = md[3]
                $log.error "error ist in #{file_name} zeile #{line} column #{col}"
                rake_gui.start_editor(file_name, line, col)
              end
            end
          end

          @table.bind(:TABLE_TRAVERSAL_EVENT) do |e|
            rake_gui.show_details_for(e.newrow)
          end

          @h_split.first_component(@table)
          @h_split.second_component(@output)
          @h_split.set_resize_weight(0.50)

          @form.repaint
          @window.wrefresh
          Ncurses::Panel.update_panels

          process_input_events
        end
      ensure
        @window.destroy if @window
        VER::stop_ncurses
      end
    end

  end



  task :ui do
    RakeGui.new.run
  end

rescue LoadError => e
end