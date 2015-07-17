using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class InterfaceLayer3 {
		public string IpAddress { get; set; }
		public List<string> HelperAddresses { get; set; }
		public Standby Standby { get; set; }
		public AccessGroup AccessGroup { get; set; }
    }
}