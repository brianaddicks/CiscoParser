using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
    public class SwitchportTrunk {
		public bool Enabled { get; set; }
		public string Encapsulation { get; set; }
		public int NativeVlan { get; set; }
		public List<int> AllowedVlans {get; set; }
    }
}