using UnityEngine;
using System.Collections;

namespace KScene
{

	public class KSceneHook  {

		/// <summary>
		/// 返回优先使用的KSceneManager
		/// </summary>
		public static System.Type GetManagerType(string sceneName)
		{
			//if (sceneName.StartsWith("XXXX_"))
			//{
			//	return typeof(XXXSceneManager); // of cause create XXXSceneManager first
			//}

			return null;
		}

	}

}
