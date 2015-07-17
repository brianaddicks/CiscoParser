using System;
using System.Xml;
using System.Web;
using System.Security.Cryptography.X509Certificates;
using System.Net;
using System.Net.Security;
using System.IO;
using System.Collections.Generic;
namespace CiscoParser {
	
    public class AccessGroup {
		public string Name { get; set; }
		public string Direction { get; set; }
    }
	
    public class AccessList {
		public string Name { get; set; }
		public string Type { get; set; }
		public string Action { get; set; }
		public List<AclRule> Rules { get; set; }
    }
	
    public class AclRule {
		public int Number { get; set; }
		public string Remark { get; set; }
		public string Protocol { get; set; }
		public string Action { get; set; }
		
		
		public string SourceAddress { get; set; }
		public string SourcePort { get; set; }
		
		public string DestinationAddress { get; set; }
		public string DestinationPort { get; set; }
    }
	
    public class Device {
		public List<Interface> Interfaces { get; set; }
		public List<AccessList> AccessLists { get; set; }
    }
	
    public class Interface {
		public string Name { get; set; }
		public string Description { get; set; }
		
		public Switchport Switchport { get; set; }
		public bool Shutdown { get; set; }
		public int Speed { get; set; }
		public string Duplex  { get; set; }
		public InterfaceLayer3 Layer3 { get; set; }
    }
	
    public class InterfaceLayer3 {
		public string IpAddress { get; set; }
		public List<string> HelperAddresses { get; set; }
		public Standby Standby { get; set; }
		public AccessGroup AccessGroup { get; set; }
    }
	
    public class Standby {
		public string IpAddress { get; set; }
		public int Priority { get; set; }
    }
	
    public class Switchport {
		public bool Enabled { get; set; }
		//public SwitchPortAccess Access { get; set; }
		//public SwitchPortTrunk Trunk { get; set; }
    }
	
    public class SwitchportAccess {
		public bool Enabled { get; set; }
		public int VLAN { get; set; }
    }
    public class SwitchportTrunk {
		public bool Enabled { get; set; }
		public string Encapsulation { get; set; }
		public List<int> AllowedVlans {get; set; }
    }
}
