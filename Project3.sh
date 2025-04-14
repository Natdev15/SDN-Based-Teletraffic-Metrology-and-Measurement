#!/bin/sh

echo "Deleting previous configuration..."
ip netns delete h1 2>/dev/null
ip netns delete h2 2>/dev/null
ip netns delete h3 2>/dev/null
ip netns delete h4 2>/dev/null

sudo ovs-vsctl --if-exists del-br OVS-br1
sudo ovs-vsctl --if-exists del-br OVS-br2
sudo ovs-vsctl --if-exists del-br OVS-br3

ip link delete br1-trunk 2>/dev/null
ip link delete br2-trunk 2>/dev/null
ip link delete br3-trunk 2>/dev/null
ip link delete br2-trunk-link 2>/dev/null
ip link delete br3-trunk-link 2>/dev/null
sleep 2

echo "Creating namespaces..."
ip netns add h1
ip netns add h2
ip netns add h3
ip netns add h4
sleep 1

echo "Creating OVS bridges..."
ovs-vsctl add-br OVS-br1
ovs-vsctl add-br OVS-br2
ovs-vsctl add-br OVS-br3

echo "Activating OVS bridges..."
ip link set OVS-br1 up
ip link set OVS-br2 up
ip link set OVS-br3 up

echo "--- Creating veth pairs..."
ip link add veth-h1 type veth peer name veth-h1-br
ip link add veth-h2 type veth peer name veth-h2-br
ip link add veth-h3 type veth peer name veth-h3-br
ip link add veth-h4 type veth peer name veth-h4-br

echo "--- Creating trunk links between OVS bridges..."
ip link add br1-trunk type veth peer name br2-trunk-link
ip link add br2-trunk type veth peer name br3-trunk-link
sleep 1

echo "Moving veth interfaces to namespaces..."
ip link set veth-h1 netns h1
ip link set veth-h2 netns h2
ip link set veth-h3 netns h3
ip link set veth-h4 netns h4
sleep 1

echo "Attaching interfaces to OVS bridges..."
ovs-vsctl add-port OVS-br1 veth-h1-br
ovs-vsctl add-port OVS-br1 veth-h2-br
ovs-vsctl add-port OVS-br3 veth-h3-br
ovs-vsctl add-port OVS-br3 veth-h4-br

ovs-vsctl add-port OVS-br1 br1-trunk
ovs-vsctl add-port OVS-br2 br2-trunk
ovs-vsctl add-port OVS-br2 br2-trunk-link
ovs-vsctl add-port OVS-br3 br3-trunk-link

echo "Configuring VLANs on trunk links..."
ovs-vsctl set port br1-trunk trunks=100,200
ovs-vsctl set port br2-trunk trunks=100,200
ovs-vsctl set port br2-trunk-link trunks=100,200
ovs-vsctl set port br3-trunk-link trunks=100,200

echo "Configuring VLAN tags on access ports..."
ovs-vsctl set port veth-h1-br tag=100
ovs-vsctl set port veth-h2-br tag=100
ovs-vsctl set port veth-h3-br tag=200
ovs-vsctl set port veth-h4-br tag=200

echo "Configuring IP addresses..."
ip -n h1 addr add 10.0.1.1/24 dev veth-h1
ip -n h2 addr add 10.0.1.2/24 dev veth-h2
ip -n h3 addr add 10.0.2.1/24 dev veth-h3
ip -n h4 addr add 10.0.2.2/24 dev veth-h4
sleep 1

echo "Turning up interfaces in namespaces..."
ip -n h1 link set lo up
ip -n h1 link set veth-h1 up
ip -n h2 link set lo up
ip -n h2 link set veth-h2 up
ip -n h3 link set lo up
ip -n h3 link set veth-h3 up
ip -n h4 link set lo up
ip -n h4 link set veth-h4 up

echo "Turning up interfaces in the default namespace..."
ip link set veth-h1-br up
ip link set veth-h2-br up
ip link set veth-h3-br up
ip link set veth-h4-br up
ip link set br1-trunk up
ip link set br2-trunk up
ip link set br2-trunk-link up
ip link set br3-trunk-link up

echo "Testing connectivity..."
ip netns exec h1 ping -c 3 10.0.1.2
ip netns exec h3 ping -c 3 10.0.2.2
ip netns exec h2 ping -c 3 10.0.1.1
ip netns exec h4 ping -c 3 10.0.2.1

echo "Configuration complete."
