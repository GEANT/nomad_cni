require 'spec_helper'

describe 'nomad_cni::macvlan::multicast::v4' do
  let :title do
    'cni_spec_test'
  end

  let(:params) do
    {
      network: '192.168.3.0/24',
      agent_list: ['test-nomad01.example.org', 'test-nomad02.example.org', 'test-nomad03.example.org'],
    }
  end

  context 'Ubuntu_20_04' do
    let(:pre_condition) do
      'class { "nomad_cni":; }'
    end
    let(:facts) do
      {
        'agent_specified_environment' => 'production',
        'os' => {
          'name' => 'Ubuntu',
          'family' => 'Debian',
          'distro' => {
            'codename' => 'focal',
          },
          'release' => {
            'major' => '20.04',
            'full' => '20.04',
          },
        },
      }
    end

    it {
      is_expected.to contain_nomad_cni__macvlan__multicast__v4('cni_spec_test').with(
        network: '192.168.3.0/24',
        agent_list: ['test-nomad01.example.org', 'test-nomad02.example.org', 'test-nomad03.example.org'],
      )
      is_expected.to contain_service('cni-id@cni_spec_test.service').with(
        ensure: 'running', enable: true,
        require: 'Systemd::Unit_file[cni-id@.service]',
        notify: 'Exec[nomad_cni reload nomad service]'
      )
      is_expected.to contain_service('cni-purge.timer').with(
        ensure: 'running',
        subscribe: 'Systemd::Timer[cni-purge.timer]',
      )
      is_expected.to contain_service('cni-up.timer').with(
        ensure: 'running',
        subscribe: 'Systemd::Timer[cni-up.timer]',
      )
    }
    # it { pp catalogue.resources }
  end

  context 'Ubuntu_22_04' do
    let(:pre_condition) do
      'class { "nomad_cni":; }'
    end
    let(:facts) do
      {
        'agent_specified_environment' => 'production',
        'os' => {
          'name' => 'Ubuntu',
          'family' => 'Debian',
          'distro' => {
            'codename' => 'jammy',
          },
          'release' => {
            'major' => '22.04',
            'full' => '22.04',
          },
        },
      }
    end

    it {
      is_expected.to contain_nomad_cni__macvlan__multicast__v4('cni_spec_test').with(
        network: '192.168.3.0/24',
        agent_list: ['test-nomad01.example.org', 'test-nomad02.example.org', 'test-nomad03.example.org'],
      )
      is_expected.to contain_service('cni-id@cni_spec_test.service').with(
        ensure: 'running', enable: true,
        require: 'Systemd::Unit_file[cni-id@.service]',
        notify: 'Exec[nomad_cni reload nomad service]'
      )
      is_expected.to contain_service('cni-purge.timer').with(
        ensure: 'running',
        subscribe: 'Systemd::Timer[cni-purge.timer]',
      )
      is_expected.to contain_service('cni-up.timer').with(
        ensure: 'running',
        subscribe: 'Systemd::Timer[cni-up.timer]',
      )
    }
  end

  context 'CentOS_7' do
    let(:pre_condition) do
      'class { "nomad_cni":; }'
    end
    let(:facts) do
      {
        'agent_specified_environment' => 'production',
        'os' => {
          'name' => 'CentOS',
          'family' => 'RedHat',
          'distro' => {
            'codename' => 'Core',
          },
          'release' => {
            'major' => '7',
            'full' => '7.4.1708',
          },
        },
      }
    end

    it {
      is_expected.to contain_nomad_cni__macvlan__multicast__v4('cni_spec_test').with(
        network: '192.168.3.0/24',
        agent_list: ['test-nomad01.example.org', 'test-nomad02.example.org', 'test-nomad03.example.org'],
      )
      is_expected.to contain_service('cni-id@cni_spec_test.service').with(
        ensure: 'running', enable: true,
        require: 'Systemd::Unit_file[cni-id@.service]',
        notify: 'Exec[nomad_cni reload nomad service]'
      )
      is_expected.to contain_service('cni-purge.timer').with(
        ensure: 'running',
        subscribe: 'Systemd::Timer[cni-purge.timer]',
      )
      is_expected.to contain_service('cni-up.timer').with(
        ensure: 'running',
        subscribe: 'Systemd::Timer[cni-up.timer]',
      )
    }
  end
end
