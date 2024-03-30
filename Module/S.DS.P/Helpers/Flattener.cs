public static class Flattener
{
    public static System.Object FlattenArray(System.Object[] arr)
    {
        if(arr==null) return null;
        switch(arr.Length)
        {
            case 0:
                return null;
            case 1:
                return arr[0];
            default:
                return arr;
        }
    }
}
