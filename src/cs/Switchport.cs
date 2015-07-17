using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class Switchport {
		public bool Enabled { get; set; }
		//public SwitchPortAccess Access { get; set; }
		//public SwitchPortTrunk Trunk { get; set; }
    }
}