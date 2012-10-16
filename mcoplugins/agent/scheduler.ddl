metadata :name        => "Part of a POC for a mco scheduler",
                     :description => "Pass an agent+action to a scheduler that runs it locally",
                     :author      => "Louis Coilliot",
                     :license     => "",
                     :version     => "1.0",
                     :url         => "http://kermit.fr",
                     :timeout     => 10

action "schedule", :description => "Schedule an action of an agent" do
    display :always

    input :agentname,
          :prompt      => "Agent name",
          :description => "The Agent to use",
          :type        => :string,
          :validation  => '^[a-zA-Z\-_\d\.:\/]+$',
          :optional    => false,
          :maxlength   => 100

    input :actionname,
          :prompt      => "Action name",
          :description => "The Action to use",
          :type        => :string,
          :validation  => '^[a-zA-Z\-_\d\.:\/]+$',
          :optional    => false,
          :maxlength   => 100

    input :schedtype,
          :prompt      => "Scheduling type",
          :description => "The type of the scheduling (in, at, cron, every, ...)",
          :type        => :string,
          :validation  => '^[a-zA-Z\-_\d\.:\/]+$',
          :optional    => true,
          :maxlength   => 100

    input :schedarg,
          :prompt      => "Scheduling argument",
          :description => "The argument the scheduling (ex : 10s)",
          :type        => :string,
          :validation  => '^[a-zA-Z\-_\d\.:\/]+$',
          :optional    => true,
          :maxlength   => 100

    input :params,
          :prompt      => "Action Parameters",
          :description => "The parameters of the action",
          :type        => :string,
          :validation  => '^[,a-zA-Z\-_\d\.:\/]+$',
          :optional    => true,
          :maxlength   => 100

   output :jobid,
          :description => "The job ID",
          :display_as  => "Job ID"
end

action "query", :description => "Query a job ID to get a status and a result" do
    display :always

    input :jobid,
          :prompt      => "Job ID",
          :description => "The job ID",
          :type        => :string,
          :validation  => '^[a-zA-Z\d]+$',
          :optional    => false,
          :maxlength   => 100

   output :state,
          :description => "The status of the Job",
          :display_as  => "State"

   output :output,
          :description => "The output of the job",
          :display_as  => "Output"
end
