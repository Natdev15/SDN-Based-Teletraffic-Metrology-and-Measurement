import time
from mininet.net import Mininet
from mininet.topo import Topo
from mininet.node import RemoteController, Controller, OVSSwitch
from mininet.link import TCLink
from mininet.cli import CLI 
from mininet.log import setLogLevel

class VlanTopology(Topo):
    def __init__(self):
        Topo.__init__(self)

    def build(self):
        """Build the topology."""
        print("Building VLAN topology")

        # Add hosts
        h1 = self.addHost("h1", ip="10.0.1.1/24", mac="00:00:00:00:01:01")
        h2 = self.addHost("h2", ip="10.0.1.2/24", mac="00:00:00:00:01:02")
        h3 = self.addHost("h3", ip="10.0.2.1/24", mac="00:00:00:00:02:01")
        h4 = self.addHost("h4", ip="10.0.2.2/24", mac="00:00:00:00:02:02")

        # Add switches in series (tail fashion)
        s1 = self.addSwitch("s1", dpid="0000000000000001")
        s2 = self.addSwitch("s2", dpid="0000000000000002")
        s3 = self.addSwitch("s3", dpid="0000000000000003")
        s4 = self.addSwitch("s4", dpid="0000000000000004")
        s5 = self.addSwitch("s5", dpid="0000000000000005")

        # Add links
        self.addLink(h1, s1)
        self.addLink(h2, s5)
        self.addLink(h3, s1)
        self.addLink(h4, s5)

        # Connect switches in a tail fashion
        self.addLink(s1, s2)
        self.addLink(s2, s3)
        self.addLink(s3, s4)
        self.addLink(s4, s5)

if __name__ == "__main__":
    setLogLevel("info")

    # Initialize the topology
    topo = VlanTopology()

    # Create the network with Open vSwitch (OVSSwitch)
    net = Mininet(
        topo=topo,
        switch=OVSSwitch,  # Specify Open vSwitch
        controller=lambda name: RemoteController(name, ip="172.17.0.2", port=6653),
        link=TCLink
    )

    # Start the network
    net.start()

    print("Configuring OpenFlow settings")

    # Set OpenFlow version for the switches
    for switch in net.switches:
        switch.cmd("ovs-vsctl set Bridge {} protocols=OpenFlow13".format(switch.name))

    # VLAN Configuration
    s1 = net.get("s1")
    s5 = net.get("s5")

    # Assign VLANs to hosts and trunk ports
    s1.cmd("ovs-vsctl add-port s1 h1 -- set port h1 tag=100")
    s1.cmd("ovs-vsctl add-port s1 h3 -- set port h3 tag=200")
    s1.cmd("ovs-vsctl set port s1-eth3 trunks=100,200")  # trunk to s2

    s5.cmd("ovs-vsctl add-port s5 h2 -- set port h2 tag=100")
    s5.cmd("ovs-vsctl add-port s5 h4 -- set port h4 tag=200")
    s5.cmd("ovs-vsctl set port s5-eth1 trunks=100,200")  # trunk to s4

    print("Testing connectivity within and across VLANs")
    h1 = net.get("h1")
    h2 = net.get("h2")
    h3 = net.get("h3")
    h4 = net.get("h4")

    time.sleep(10)
    print("Ping within VLAN 100 (h1 -> h2):")
    net.ping([h1, h2])

    print("Ping within VLAN 200 (h3 -> h4):")
    net.ping([h3, h4])

    print("Ping across VLANs (h1 -> h3):")
    net.ping([h1, h3])

    print("Launching CLI")
    CLI(net)

    print("Stopping network")
    net.stop()
