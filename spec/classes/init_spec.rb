require 'spec_helper'

describe 'nomad_cni' do
  let(:params) do
    {
      manage_firewall_vxlan: true,
      cni_cut_off: true,
      vip_address: '192.168.100.10/24',
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
      is_expected.to contain_class('nomad_cni').with(manage_firewall_vxlan: true, cni_cut_off: true, vip_address: '192.168.100.10/24')
      is_expected.to contain_class('nomad_cni::config').with(
        cni_version: '1.4.1',
        cni_base_url: 'https://github.com/containernetworking/plugins/releases/download',
        keep_vxlan_up_timer_interval: 1,
        keep_vxlan_up_timer_unit: 'minutes',
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
      is_expected.to contain_file('/opt/cni/vxlan/unicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast-bridge-fdb.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/usr/local/bin/cni-validator.rb').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/nomad_cni/cni-validator.rb')
      is_expected.to contain_file('/usr/local/bin/cni-vxlan-wizard.sh').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/nomad_cni/cni-vxlan-wizard.sh')
      is_expected.to contain_package('docopt').with(ensure: 'present', provider: 'gem')
      is_expected.to contain_package('fping').with(ensure: 'present')
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
      is_expected.to contain_class('nomad_cni').with(manage_firewall_vxlan: true, cni_cut_off: true, vip_address: '192.168.100.10/24')
      is_expected.to contain_class('nomad_cni::config').with(
        cni_version: '1.4.1',
        cni_base_url: 'https://github.com/containernetworking/plugins/releases/download',
        keep_vxlan_up_timer_interval: 1,
        keep_vxlan_up_timer_unit: 'minutes',
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
      is_expected.to contain_file('/opt/cni/vxlan/unicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast-bridge-fdb.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/usr/local/bin/cni-validator.rb').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/nomad_cni/cni-validator.rb')
      is_expected.to contain_file('/usr/local/bin/cni-vxlan-wizard.sh').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/nomad_cni/cni-vxlan-wizard.sh')
      is_expected.to contain_package('docopt').with(ensure: 'present', provider: 'gem')
      is_expected.to contain_package('fping').with(ensure: 'present')
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
      is_expected.to contain_class('nomad_cni').with(manage_firewall_vxlan: true, cni_cut_off: true, vip_address: '192.168.100.10/24')
      is_expected.to contain_class('nomad_cni::config').with(
        cni_version: '1.4.1',
        cni_base_url: 'https://github.com/containernetworking/plugins/releases/download',
        keep_vxlan_up_timer_interval: 1,
        keep_vxlan_up_timer_unit: 'minutes',
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
      is_expected.to contain_file('/opt/cni/vxlan/unicast.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/opt/cni/vxlan/unicast-bridge-fdb.d').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755', purge: true, recurse: true, force: true)
      is_expected.to contain_file('/usr/local/bin/cni-validator.rb').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/nomad_cni/cni-validator.rb')
      is_expected.to contain_file('/usr/local/bin/cni-vxlan-wizard.sh').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/nomad_cni/cni-vxlan-wizard.sh')
      is_expected.to contain_package('docopt').with(ensure: 'present', provider: 'gem')
      is_expected.to contain_package('fping').with(ensure: 'present')
    }
  end
end
