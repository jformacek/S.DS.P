[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
Add-Type @'
    using System;
    using System.Collections.Generic;
    using System.Linq;

    public class DistinguishedName
    {
        private readonly static char _delimiter = ',';
        private readonly static char _escape = '\\';
        private string _distinguishedName;

        public List<DistinguishedNameToken> Segments { get; set; }
        public override string ToString()
        {
            //performance optimization - return original string instead of parsed and reconstructed
            return _distinguishedName;
            //return string.Join(_delimiter.ToString(), Segments.Select(x => x.ToString()));
        }
        public DistinguishedName(string distinguishedName)
        {
            _distinguishedName = distinguishedName;
            Segments = new List<DistinguishedNameToken>();
            int start = 0;
            for (int i = 0; i < distinguishedName.Length; i++)
            {
                if (distinguishedName[i] == _delimiter && distinguishedName[i - 1] != _escape)
                {
                    Segments.Add(new DistinguishedNameToken(distinguishedName.Substring(start, i - start)));
                    start = i + 1;
                }
            }
            Segments.Add(new DistinguishedNameToken(distinguishedName.Substring(start)));
        }
    }

    public class DistinguishedNameToken
    {
        private readonly static char[] _escapedChars = new char[] { ',', '\\', '#', '+', '<', '>', ';', '"', '=', '/' };
        private readonly static char _delimiter = '=';
        private readonly static char _escape = '\\';

        protected string Unescape(string value)
        {
            var result = new List<char>();
            for (int i = 0; i < value.Length; i++)
            {
                if (value[i] == _escape && value[i + 1] == '0')
                {
                    if (value[i + 2] == 'D')
                    {
                        result.Add('\r');
                        i += 2;
                        continue;
                    }
                    if (value[i + 2] == 'A')
                    {
                        result.Add('\n');
                        i += 2;
                        continue;
                    }
                }
                //first space is escaped
                if (i == 0 && value[i] == _escape)
                {
                    continue;
                }
                //last space is escaped
                if (i == value.Length-2 && value[i] == _escape)
                {
                    continue;
                }
                if (value[i] == _escape)
                {
                    if (i + 1 < value.Length && _escapedChars.Contains(value[i + 1]))
                    {
                        result.Add(value[i + 1]);
                        i++;
                    }
                    else
                    {
                        result.Add(value[i]);
                    }
                }
                else
                {
                    result.Add(value[i]);
                }
            }
            return new string(result.ToArray());
        }

        protected string Escape(string value)
        {
            var result = new List<char>();
            for (int i = 0; i < value.Length; i++)
            {
                //escaping only first and last space
                if (value[i] == ' ' && (i == 0 || i == value.Length - 1))
                {
                    result.Add(_escape);
                }
                if (value[i] == '\r')
                {
                    result.Add(_escape);
                    result.Add('0');
                    result.Add('D');
                    continue;
                }
                if (value[i] == '\n')
                {
                    result.Add(_escape);
                    result.Add('0');
                    result.Add('A');
                    continue;
                }
                if (_escapedChars.Contains(value[i]))
                {
                    result.Add(_escape);
                }
                result.Add(value[i]);
            }
            return new string(result.ToArray());
        }

        public string Qualifier { get; set; }
        public string Value { get; set; }

        public DistinguishedNameToken(string token)
        {
            var start = token.IndexOf(_delimiter);
            Qualifier = token.Substring(0, start).Trim();
            Value = Unescape(token.Substring(start + 1));
        }
        public override string ToString()
        {
            return string.Format("{0}{1}{2}", Qualifier, _delimiter, Escape(Value));
        }
    }
'@
}

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('distinguishedName','member','memberOf')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            new-object DistinguishedName($Value)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [DistinguishedName[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $Value.ToString()
        }
    }
}
$codeBlock
