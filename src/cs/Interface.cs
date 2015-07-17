using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class Interface {
		public string Name { get; set; }
		public string Description { get; set; }
		
		public Switchport Switchport { get; set; }
		public bool Shutdown { get; set; }
		public int Speed { get; set; }
		public string Duplex  { get; set; }
		public InterfaceLayer3 Layer3 { get; set; }
		
		public ChannelGroup ChannelGroup  { get; set; }
		
		public Interface () {
			this.Switchport = new Switchport {};
			this.Layer3 = new InterfaceLayer3 {};
			this.ChannelGroup = new ChannelGroup {};
		}
    }
}