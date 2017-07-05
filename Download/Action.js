//
//  Action.js
//  Download
//
//  Created by James Froggatt on 16.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

var Action = function() {};

Action.prototype = {
    
    run: function(arguments) {
			arguments.completionFunction({"URL": document.URL});
    },
    
    finalize: function(arguments) {
			var newURL = arguments["URL"];
			if (newURL) {
				location.href = newURL;
			}
		}
    
};
    
var ExtensionPreprocessingJS = new Action
