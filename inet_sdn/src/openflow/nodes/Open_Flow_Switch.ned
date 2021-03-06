//
// Copyright (C) 2004 Andras Varga
// Copyright (C) 2000 Institut fuer Telematik, Universitaet Karlsruhe
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program; if not, see <http://www.gnu.org/licenses/>.
//


package inet.openflow.nodes;

import inet.applications.pingapp.PingApp;
import inet.applications.ITCPApp;
import inet.base.NotificationBoard;
import inet.linklayer.ethernet.EtherMAC;
import inet.linklayer.ethernet.EthernetInterface;
import inet.linklayer.ext.ExtInterface;
import inet.linklayer.ppp.PPPInterface;
import inet.networklayer.common.InterfaceTable;
import inet.networklayer.ipv4.RoutingTable;
import inet.transport.ITCP;
import inet.transport.udp.UDP;
import inet.util.TCPDump;
import inet.nodes.inet.NetworkLayer;
import inet.openflow.*;


// OpenFlow switch based on the OF Switch Specification 1.2.
// New implemented modules: FlowTable, Open_Flow_Processing, Buffer, OFA_Switch (Application)
// The OpenFlow switch is basically divided in two parts. The left path, which
//consists of a EtherMAC and a OpenFlowProcessing module, represents the data plane.
//All production traffic, coming from different nodes connected
//to the switch, is handled here. The Processing module performs packet lookups in the 
//flow table and executes instructions, if a matching entry is found.
//The right part with the modules EthernetInterface, NetworkLayer, TCP and
//OFASwitch is responsible for the communication with a remote controller via the
//OpenFlow protocol and is called control plane.
module Open_Flow_Switch 
{
    parameters:
        @node();
        @OF_Switch();
        @labels(node,ethernet-node);
        @display("i=device/switch;i2=OpenFlow-Logo-small");
        int numTcpApps = default(0);
        int numUdpApps = default(0);
        int numSctpApps = default(0);
        string tcpAppType = default("n/a");
        string udpAppType = default("n/a");
        string sctpAppType = default("n/a");
        string tcpType = default("TCP");  // tcp implementation (e.g. TCP, TCP_old, TCP_NSC)
        bool IPForward = default(false);
        int namid = default(-1);
        string routingFile = default("");
        int numExtInterfaces = default(0);
        bool sendCompletePacket = default(false);
        double serviceTime @unit("s") = default(0s);
    gates:
        inout gate_controller[] @labels(Controller-conn);
        inout ethg[] @labels(EtherFrame-conn);
    submodules:    	
        notificationBoard: NotificationBoard {
            parameters:
                @display("p=57,54");
        }
        interfaceTable: InterfaceTable {
            parameters:
                @display("p=57,134");
        }
         routingTable: RoutingTable {
            parameters:
                IPForward = IPForward;
                routerId = "";
                routingFile = routingFile;
                @display("p=57,214");
        }
		tcp: <tcpType> like ITCP {
            parameters:
                @display("p=336,159");
        }
        networkLayer: NetworkLayer {
            parameters:
                proxyARP = false;
                @display("p=336,262;q=queue");
            gates:
                ifIn[sizeof(gate_controller)];
                ifOut[sizeof(gate_controller)];
        }
        eth[sizeof(gate_controller)]: EthernetInterface {
            parameters:
                @display("p=336,390,row,90;q=txQueue");
        }
        flow_Table: Flow_Table {
            @display("p=192,134");
        }
        etherMAC[sizeof(ethg)]: EtherMAC {
            parameters:
                @display("p=192,383");
                doRegisterAtIft = true;
        }
        open_Flow_Processing: Open_Flow_Processing {
            @display("p=192,262");
            serviceTime = serviceTime;
            gates:
                ifIn[sizeof(ethg)];
                ifOut[sizeof(ethg)];
        }
        buffer: Buffer {
            @display("p=192,53");
        }
        ofa_switch: OFA_switch {
            @display("p=336,71");
            sendCompletePacket = sendCompletePacket;
        }
    connections allowunconnected:
        tcp.ipOut --> networkLayer.transportIn++; 
        tcp.ipIn <-- networkLayer.transportOut++;

        for i=0..sizeof(gate_controller)-1 {
            eth[i].phys <--> gate_controller[i];
            eth[i].upperLayerOut --> networkLayer.ifIn[i];
            eth[i].upperLayerIn <-- networkLayer.ifOut[i];
        }

        for i=0..sizeof(ethg)-1 {
            etherMAC[i].phys <--> ethg[i];
            open_Flow_Processing.ifOut[i] --> etherMAC[i].upperLayerIn;
            etherMAC[i].upperLayerOut --> open_Flow_Processing.ifIn[i];

        }
        tcp.appOut++ --> ofa_switch.tcpIn;
        ofa_switch.tcpOut --> tcp.appIn++;
}
