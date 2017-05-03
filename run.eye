# Eye self-configuration section
Eye.config do
  logger '/tmp/eye.log'
end

# Adding application
Eye.application 'canillitapp' do
  working_dir File.expand_path(File.join(File.dirname(__FILE__)))
  stdall 'trash.log' # stdout,err logs for processes by default
  
  process :canillitapp_server do
    pid_file 'canillitapp_server.pid' # pid_path will be expanded with the working_dir
      start_command 'bundle exec rackup -p4567 --host 0.0.0.0 -E development -s Puma'

      # when no stop_command or stop_signals, default stop is [:TERM, 0.5, :KILL]
      # default `restart` command is `stop; start`

      daemonize true
      stdall 'canillitapp_server.log'

      # ensure the CPU is below 30% at least 3 out of the last 5 times checked
      check :cpu, below: 70, times: [3, 5]
  end
  
  process :canillitapp_news_fetcher do
    pid_file 'canillitapp_fetch_news.pid'
      start_command 'ruby fetcher_job.rb'
      daemonize true
      stdall 'canillitapp_fetch_news.log'
  end
end
