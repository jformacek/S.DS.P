public class NamingContext
{
    public System.Security.Principal.SecurityIdentifier SID {get; set;}
    public System.Guid GUID {get; set;}
    public string distinguishedName {get; set;}
    public override string ToString() {return distinguishedName;}
    public static NamingContext Parse(string ctxDef)
    {
        NamingContext retVal = new NamingContext();
        var parts = ctxDef.Split(';');
        if(parts.Length == 1)
        {
            retVal.distinguishedName = parts[0];
        }
        else
        {
            foreach(string part in parts)
            {
                if(part.StartsWith("<GUID="))
                {
                    try
                    {
                        retVal.GUID=System.Guid.Parse(part.Substring(6,part.Length-7));
                    }
                    catch(System.Exception)
                    {
                        //swallow any errors
                    }
                    continue;
                }
                if(part.StartsWith("<SID="))
                {
                    try
                    {
                        retVal.SID=new System.Security.Principal.SecurityIdentifier(part.Substring(5,part.Length-6));
                    }
                    catch(System.Exception)
                    {
                        //swallow any errors
                    }
                    continue;
                }
                retVal.distinguishedName=part;
            }
        }
        return retVal;
    }
}
