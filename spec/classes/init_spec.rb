require 'spec_helper'

describe 'nomad_cni' do
  let(:params) do
    {
      manage_firewall_vxlan: true,
      cni_cut_off: true,
    }
  end

  context 'Ubuntu_20_04' do
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
      is_expected.to contain_class('nomad_cni').with(manage_firewall_vxlan: true, cni_cut_off: true)
      is_expected.to contain_class('nomad_cni::config').with(
        cni_version: '1.2.0',
        cni_base_url: 'https://github.com/containernetworking/plugins/releases/download',
        keep_vxlan_up_cron_interval: 5,
      )
      is_expected.to contain_class('nomad_cni::firewall::chain').with(provider: ['iptables'], rule_order: '050')
      is_expected.to contain_class('nomad_cni::firewall::nat').with(
        interface: 'eth0',
        rule_order: '050',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_class('nomad_cni::firewall::vxlan').with(
        interface: 'eth0',
        rule_order: '051',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_class('nomad_cni::firewall::cni_cut_off').with(
        rule_order: '060',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_exec('create custom fact directories from nomad_cni').with(command: 'install -o root -g root -d /etc/facter/facts.d')
      is_expected.to contain_file('/etc/facter/facts.d/nomad_cni_firewall_rule_order.yaml').with(
        content: "---\ncni_connect_rule_order: \"051\"\n",
      )
      is_expected.to contain_file('/opt/cni/vxlan/multicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast_bridge_fdb.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
    }
  end

  context 'Ubuntu_22_04' do
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
      is_expected.to contain_class('nomad_cni').with(manage_firewall_vxlan: true, cni_cut_off: true)
      is_expected.to contain_class('nomad_cni::config').with(
        cni_version: '1.2.0',
        cni_base_url: 'https://github.com/containernetworking/plugins/releases/download',
        keep_vxlan_up_cron_interval: 5,
      )
      is_expected.to contain_class('nomad_cni::firewall::chain').with(provider: ['iptables'], rule_order: '050')
      is_expected.to contain_class('nomad_cni::firewall::nat').with(
        interface: 'eth0',
        rule_order: '050',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_class('nomad_cni::firewall::vxlan').with(
        interface: 'eth0',
        rule_order: '051',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_class('nomad_cni::firewall::cni_cut_off').with(
        rule_order: '060',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_exec('create custom fact directories from nomad_cni').with(command: 'install -o root -g root -d /etc/facter/facts.d')
      is_expected.to contain_file('/etc/facter/facts.d/nomad_cni_firewall_rule_order.yaml').with(
        content: "---\ncni_connect_rule_order: \"051\"\n",
      )
      is_expected.to contain_file('/opt/cni/vxlan/multicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast_bridge_fdb.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
    }
  end

  context 'CentOS_7' do
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
      is_expected.to contain_class('nomad_cni').with(manage_firewall_vxlan: true, cni_cut_off: true)
      is_expected.to contain_class('nomad_cni::config').with(
        cni_version: '1.2.0',
        cni_base_url: 'https://github.com/containernetworking/plugins/releases/download',
        keep_vxlan_up_cron_interval: 5,
      )
      is_expected.to contain_class('nomad_cni::firewall::chain').with(provider: ['iptables'], rule_order: '050')
      is_expected.to contain_class('nomad_cni::firewall::nat').with(
        interface: 'eth0',
        rule_order: '050',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_class('nomad_cni::firewall::vxlan').with(
        interface: 'eth0',
        rule_order: '051',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_class('nomad_cni::firewall::cni_cut_off').with(
        rule_order: '060',
        provider: ['iptables'],
        require: 'Class[Nomad_cni::Firewall::Chain]',
      )
      is_expected.to contain_exec('create custom fact directories from nomad_cni').with(command: 'install -o root -g root -d /etc/facter/facts.d')
      is_expected.to contain_file('/etc/facter/facts.d/nomad_cni_firewall_rule_order.yaml').with(
        content: "---\ncni_connect_rule_order: \"051\"\n",
      )
      is_expected.to contain_file('/opt/cni/vxlan/multicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast_bridge_fdb.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
    }
  end
end
