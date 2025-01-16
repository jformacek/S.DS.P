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
    public List<DistinguishedNameToken> Segments { get; set; }
    public override string ToString()
    {
        return string.Join(_delimiter.ToString(), Segments.Select(x => x.ToString()));
    }
    public DistinguishedName(string distinguishedName)
    {
        Segments = new List<DistinguishedNameToken>();
        int start = 0;
        for (int i = 0;i < distinguishedName.Length; i++)
        {
            if (distinguishedName[i] == _delimiter && distinguishedName[i-1] != _escape)
            {
                Segments.Add(new DistinguishedNameToken(distinguishedName.Substring(start, i-start)));
                start = i + 1;
            }
        }
        Segments.Add(new DistinguishedNameToken(distinguishedName.Substring(start)));
    }
}

public class DistinguishedNameToken
{
    private readonly static char[] _escapedChars = new char[] { ',', '\\', '#', '+', '<', '>', ';', '"', '=','/' };
    private readonly static char _delimiter = '=';
    private readonly static char _escape = '\\';

    protected string Unescape(string value)
    {
        var result = new List<char>();
        for (int i = 0; i < value.Length; i++)
        {
            if(i== 0 && value[i] == _escape)
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
            if(i == 0 && value[i] == ' ')
            {
                result.Add(_escape);
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
        Qualifier = token.Substring(0,start).Trim();
        Value = Unescape(token.Substring(start+1));
    }
    public override string ToString()
    {
        return string.Format("{0}{1}{2}",Qualifier,_delimiter,Escape(Value));
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
