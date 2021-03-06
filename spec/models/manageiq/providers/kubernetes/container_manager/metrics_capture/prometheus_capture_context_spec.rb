describe ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::PrometheusCaptureContext do
  before(:each) do
    @record = :none
    # @record = :new_episodes

    master_hostname = 'master.example.com'
    hostname = 'prometheus.example.com'
    token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtYW5hZ2VtZW50LWluZnJhIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im1hbmFnZW1lbnQtYWRtaW4tdG9rZW4tZnJyeDgiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoibWFuYWdlbWVudC1hZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjRhODY5NDczLWQ1ZGQtMTFlNy1iNjhlLTAwMWE0YTE2MjZiZCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDptYW5hZ2VtZW50LWluZnJhOm1hbmFnZW1lbnQtYWRtaW4ifQ.UhGy45pjWTak0NznD1v2rQtbf-XYis_5_ZKqVL0o7_4NFc69hsZZ4i_pSl2Pb4qsyNhWyZRY0JpKmBDz8CXIiZTb92laqrg_QQO4qMxo1nn2dHq_8nsMfdMAzR_dDzbUAlyPjhLMqUU9CecWzTodZ_PxLEfjZpMw8qIVAtca5fl5xgK1TbvnBdbnD_wK57PphadAZ1MCUdgzNgrs58WC59R1dv0lCL15UEXxamowLDZy1zWOG-WiHxFz5wN5iN7KCkPMnABOLoQ4k53kg-4sZzwqCPziUqyWm0mer2TwLzhqkuztzJnQ9AQBtt1kWvFKmPfGDUZ91bfGNfKeyd1gFw'

    @ems = FactoryBot.create(
      :ems_kubernetes_with_zone,
      :name                      => 'KubernetesProvider',
      :connection_configurations => [{:endpoint       => {:role       => :default,
                                                          :hostname   => master_hostname,
                                                          :port       => "8443",
                                                          :verify_ssl => false},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role       => :prometheus,
                                                          :hostname   => hostname,
                                                          :port       => "443",
                                                          :verify_ssl => false},
                                      :authentication => {:role     => :prometheus,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )

    VCR.use_cassette("#{described_class.name.underscore}_refresh",
                     :match_requests_on => [:path,], :record => @record) do
      EmsRefresh.refresh(@ems)
      @ems.reload

      @node = @ems.container_nodes.last
      pod = @ems.container_groups.last
      container = @ems.containers.last
      @targets = [['node', @node], ['pod', pod], ['container', container]]
    end
  end

  it "will read prometheus metrics" do
    start_time = Time.parse("2017-12-27 07:30:00 UTC").utc
    end_time   = Time.parse("2017-12-27 07:40:00 UTC").utc
    interval   = 60

    @targets.each do |target_name, target|
      VCR.use_cassette("#{described_class.name.underscore}_#{target_name}_metrics", :record => @record) do
        context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::PrometheusCaptureContext.new(
          target, start_time, end_time, interval
        )

        data = context.collect_metrics

        expect(data).to be_a_kind_of(Hash)
      end
    end
  end

  it "will read only specific timespan prometheus metrics" do
    start_time = Time.parse("2017-12-27 07:30:00 UTC").utc
    end_time   = Time.parse("2017-12-27 07:40:00 UTC").utc
    interval   = 60

    @targets.each do |target_name, target|
      VCR.use_cassette("#{described_class.name.underscore}_#{target_name}_timespan", :record => @record) do
        context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::PrometheusCaptureContext.new(
          target, start_time, end_time, interval
        )

        data = context.collect_metrics

        expect(data.count).to be > 8
        expect(data.count).to be < 13
      end
    end
  end
end
