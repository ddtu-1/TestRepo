using System;
using System.Collections.Generic;
namespace NetCoreConsoleApp
{
    /// <summary>innertext
    /// </summary>
    /// <typeparam name="attribute" />
    public class Classifications : AClass
    {
        public static void Method(string param)
        {
            Console.WriteLine("Hello");
            List<Exception> list = new List<Exception>();
            Classifications.Method(null);
        }
    }
}
