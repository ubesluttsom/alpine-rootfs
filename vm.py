#!/usr/bin/env python3
from dataclasses import dataclass, field
from ipaddress import IPv4Network
from logging import info, error
from typing import Dict, List, Optional, Tuple
import argparse
import json
import logging
import matplotlib.pyplot as plt
import networkx as nx
import os
import socket
import subprocess
import sys
import time

logging.basicConfig(level=logging.INFO)


@dataclass(unsafe_hash=True)
class VM:
    name: str
    ssh_port: int = field(hash=False, compare=False)
    links: List[str] = field(hash=False, compare=False, default_factory=list)


def build_graph(vm_configs: Dict[str, VM]) -> nx.Graph:
    graph = nx.Graph()
    for vm in vm_configs.values():
        graph.add_node(vm.name, ssh_port=vm.ssh_port)
        for link in vm.links:
            graph.add_edge(vm.name, link)
    if not nx.is_tree(graph):
        error("Network configuration is not a tree.")
        sys.exit(1)
    if not nx.is_connected(graph):
        error("Network is not fully connected.")
        sys.exit(1)
    return graph


def assign_ports_and_directions(graph: nx.Graph, root: str) -> nx.DiGraph:
    ports_graph = nx.bfs_tree(graph, root)
    for edge in ports_graph.edges():
        ports_graph.edges[edge]["port"] = find_available_port()
    return ports_graph


def find_available_port() -> int:
    """Find some random avalible port. Subject to race conditions."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("", 0))
    _, port = s.getsockname()
    s.close()
    return port


def check_port_available(port: int) -> bool:
    """Check if a specified port is available on localhost."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("localhost", port)) == 0


def wait_for_port(port: int, timeout=300) -> bool:
    """Wait for a port on localhost to become available."""
    start_time = time.time()
    while time.time() - start_time < timeout:
        if check_port_available(port):
            info(f"Port {port} is now available.")
            return True
        time.sleep(1)
    error(f"Timeout waiting for port {port}")
    return False


def wait_for_ports(vm: str, ports_graph: nx.Graph) -> None:
    ports = nx.get_edge_attributes(ports_graph, "port")
    for (_, listens_for), port in ports.items():
        if listens_for == vm:
            wait_for_port(port)


def load_vm_configs(filename: str) -> Dict[str, VM]:
    if not os.path.exists(filename):
        error(f"No VM configuration found at {filename}")
        sys.exit(1)
    with open(filename, "r") as f:
        data = json.load(f)
    result = {}
    for name, cfg in data.items():
        result[name] = VM(name, cfg["ssh_port"], cfg["links"])
    return result


def load_graph_json(filename: str) -> nx.Graph:
    if not os.path.exists(filename):
        error(f"No assignments found at {filename}")
        sys.exit(1)
    with open(filename, "r") as f:
        return nx.node_link_graph(json.load(f))


def build_vm_commands(vm: str, vms: nx.Graph, ports_graph: nx.DiGraph) -> List[str]:
    net_args = []
    ports = nx.get_edge_attributes(ports_graph, "port")
    for neighbor in vms.neighbors(vm):
        port = ports.get((vm, neighbor), ports.get((neighbor, vm)))
        mode = "connect" if (neighbor, vm) in ports_graph.edges else "listen"
        net_args.extend(
            [
                "-netdev",
                f"socket,id=net{neighbor},{mode}=:{port}",
                "-device",
                f"e1000,netdev=net{neighbor}",
                "-object",
                f"filter-dump,id=filter{neighbor},netdev=net{neighbor},file=/tmp/{vm}-{neighbor}.pcap",
            ]
        )
    ssh_port = vms.nodes[vm]["ssh_port"]
    command = [
        "qemu-system-aarch64",
        "-m",
        "1024",
        "-cpu",
        "cortex-a72",
        "-M",
        "virt",
        "-nographic",
        "--no-reboot",
        "-kernel",
        "../linux/arch/arm64/boot/Image",
        "-append",
        f'"console=ttyAMA0 root=/dev/vda vm={vm}"',
        "-drive",
        "file=../alpine-rootfs/rootfs.img,format=raw,snapshot=on",
        "-netdev",
        f"user,id=netuser,net=192.168.100.0/24,hostfwd=tcp::{ssh_port}-:22",
        "-device",
        "e1000,netdev=netuser",
        *net_args,
    ]
    return command


def save_vm_scripts(
    vms: nx.Graph,
    ports_graph: nx.DiGraph,
    directory: str = "vm-scripts",
) -> None:
    """Generate and save individual VM startup scripts based on configurations."""
    os.makedirs(directory, exist_ok=True)

    # Write ports assignments
    port_path = os.path.join(directory, "ports.json")
    with open(port_path, "w") as f:
        json.dump(nx.node_link_data(ports_graph), f)

    # Write IP assignments
    assignments_path = os.path.join(directory, "ips.json")
    with open(assignments_path, "w") as f:
        json.dump(nx.node_link_data(vms), f)

    # Write VM scripts
    for vm in vms.nodes:
        script_path = os.path.join(directory, f"{vm}.sh")
        with open(script_path, "w") as f:
            f.write("#!/bin/sh\n")
            f.write(" ".join(build_vm_commands(vm, vms, ports_graph)))
            os.chmod(script_path, 0o755)
        info(f"Generated script for {vm}")


def assign_subnets(
    graph: nx.Graph,
    node: str,
    network: IPv4Network = IPv4Network("10.0.0.0/8"),
    parent: Optional[str] = None,
) -> None:
    """Assign subnets to all links in a network"""
    # Get sufficient subnets for the given network; increase mask
    needed_bits = int(graph.degree[node] - 1).bit_length()
    subnets = list(network.subnets(prefixlen_diff=needed_bits))

    # Don't use 0th subnet, reserve that for parent link
    if parent:
        subnets.pop(0)

    # Assign subnets to each neighbor except the parent
    for neighbor in graph.neighbors(node):
        if neighbor == parent:
            continue
        child_subnet = subnets.pop(0)
        graph.edges[node, neighbor]["subnet"] = str(child_subnet)
        assign_subnets(graph, neighbor, child_subnet, node)


def assign_ips(graph: nx.Graph) -> None:
    """Assign IP addresses to all interfaces."""
    for n1, n2, data in graph.edges(data=True):
        # Get the subnet and generate the /30 subnet
        subnet = IPv4Network(data["subnet"])
        subnet_30 = next(subnet.subnets(new_prefix=30))

        # Get the two usable IPs in the /30 subnet
        interface_ip = tuple(map(str, subnet_30.hosts()))

        # Assign IPs to the edge
        data["ip"] = (interface_ip[0], interface_ip[1])

        # Initialize interfaces for nodes if not present
        for node in (n1, n2):
            if "interfaces" not in graph.nodes[node]:
                graph.nodes[node]["interfaces"] = {}

        # Assign interfaces to nodes
        graph.nodes[n1]["interfaces"][n2] = (interface_ip[0], str(subnet))
        graph.nodes[n2]["interfaces"][n1] = (interface_ip[1], str(subnet))


def find_interface_with_lowest_netmask(
    interfaces: Dict[str, Tuple[str, str]]
) -> Optional[Tuple[str, str]]:
    return min(
        interfaces.values(),
        key=lambda item: IPv4Network(item[1], strict=False).prefixlen,
        default=None,
    )


def generate_network_interfaces_config(vm: str, graph: nx.Graph) -> str:
    """Generate configurations for /etc/network/interfaces."""
    data = graph.nodes[vm]
    interfaces = data.get("interfaces", {})

    # Add default route for 10.0.0.0/8 network using the interface with the lowest netmask
    if lowest_netmask_iface := find_interface_with_lowest_netmask(interfaces):
        iface_entries = [
            f"auto eth0\n"
            f"iface eth0 inet dhcp\n"
            f"    post-up ip route add 10.0.0.0/8 via {lowest_netmask_iface[0]}\n"
        ]
    else:
        iface_entries = ["auto eth0\n" "iface eth0 inet dhcp\n"]

    neighbors = list(graph.neighbors(vm))

    for neighbor, (ip, subnet) in interfaces.items():
        iface_name = f"eth{neighbors.index(neighbor) + 1}"
        net = IPv4Network(subnet, strict=False)
        iface_entries.append(
            f"auto {iface_name}\n"
            f"iface {iface_name} inet static\n"
            f"    address {ip}\n"
            f"    netmask {net.netmask}\n"
            f"    post-up ip route add {str(net)} via {ip}\n"
        )

    return "\n".join(iface_entries)


def visualize_network(graph: nx.Graph, ports_graph: nx.Graph) -> None:
    # Generate positions for nodes in the graph
    pos = nx.kamada_kawai_layout(graph)

    # Draw the ports graph with labels and arrows
    nx.draw(
        ports_graph,
        pos,
        with_labels=True,
        arrows=True,
        arrowsize=15,
        node_color="lightblue",
        edge_color="lightblue",
        font_weight="bold",
        node_size=2000,
    )

    # Extract port and subnet labels from the graphs
    port_labels = nx.get_edge_attributes(ports_graph, "port")
    subnet_labels = nx.get_edge_attributes(graph, "subnet")

    # Combine port and subnet labels for edges
    edge_labels = {}
    for edge in port_labels:
        port = port_labels[edge]
        subnet = subnet_labels.get(edge, subnet_labels.get((edge[1], edge[0])))
        edge_labels[edge] = f"{port}\n{subnet}"

    # Draw edge labels
    nx.draw_networkx_edge_labels(
        ports_graph, pos, edge_labels=edge_labels, font_color="red"
    )

    # Set the title and display the plot
    plt.title("Network Topology with Assignments")
    plt.show()


def main():
    parser = argparse.ArgumentParser(
        description="Manage VM configurations and startup."
    )
    parser.add_argument("--config", help="Path to VM configuration JSON file")
    parser.add_argument("--ports", help="Path to assigned ports JSON file")
    parser.add_argument("--ips", help="Path to assigned IP addesses JSON file")
    parser.add_argument(
        "--generate", action="store_true", help="Generate VM startup scripts"
    )
    parser.add_argument("--visualize", action="store_true", help="Visualize network")
    parser.add_argument(
        "--interfaces",
        action="store_true",
        help="Print interface configuration for a spesific VM",
    )
    parser.add_argument("vm_name", nargs="?", help="Name of the VM to start")
    args = parser.parse_args()

    vm_configs = load_vm_configs(args.config if args.config else "vms.json")

    if args.generate:
        graph = build_graph(vm_configs)
        root = nx.center(graph)[0]
        ports_graph = assign_ports_and_directions(graph, root)
        assign_subnets(graph, root)
        assign_ips(graph)
        save_vm_scripts(graph, ports_graph)
        info("Generated VM startup scripts and port/IP assignments.")
        sys.exit(0)

    ports_graph = load_graph_json(args.ports if args.ports else "vm-scripts/ports.json")
    graph = load_graph_json(args.ips if args.ips else "vm-scripts/ips.json")

    if args.visualize:
        visualize_network(graph, ports_graph)
    elif args.vm_name:
        if args.interfaces:
            print(generate_network_interfaces_config(args.vm_name, graph), end="")
            sys.exit(0)
        script_path = f"vm-scripts/{args.vm_name}.sh"
        if os.path.exists(script_path):
            wait_for_ports(args.vm_name, ports_graph)
            subprocess.run([script_path], check=True)
        else:
            error(f"No script found for {args.vm_name}")
    elif args.interfaces:
        directory = "vm-interfaces"
        os.makedirs(directory, exist_ok=True)
        for vm in vm_configs.keys():
            with open(os.path.join(directory, vm), "w") as f:
                f.write(generate_network_interfaces_config(vm, graph))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
