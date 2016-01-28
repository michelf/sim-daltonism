
Sim Daltonism for Mac and iOS
===============================

Website: <https://michelf.ca/projects/sim-daltonism/>

Sim Daltonism is a color blindness simulator for iOS and Mac. It takes a live 
video feed from the camera on iOS and filters it in real time using a color 
blindness simulation algorithm.

<img src="https://michelf.ca/img/shots/sim-daltonism/ios/toys.jpg" width="320" height="480" />
<img src="https://michelf.ca/img/shots/sim-daltonism/ios/raspberries.jpg" width="320" height="480" /> 

The Mac version has a filter window that shows the content underneath the 
window filtered.

<img src="https://michelf.ca/img/shots/sim-daltonism/sim-d.en.4.jpg" width="640" height="400" />


Origins
-------

The application is almost a clone of [Red Stripe][] where the filter 
algorithm has been replaced with an OpenGL adaptation of the `color_blind_sim`
javascript function found on the [Color Laboratory][]. The video capture and 
live filtering code is taken in part from the [RosyWriter][] sample code
provided by Apple. 

[Red Stripe]: https://michelf.ca/software/red-stripe/
[Color Laboratory]: http://colorlab.wickline.org/colorblind/colorlab/
[RosyWriter]: https://developer.apple.com/library/ios/samplecode/RosyWriter/Introduction/Intro.html

This application shares a lot with my other app Red Stripe. I welcome 
contributions. Note that contribution accepted in Sim Daltonism will often 
land into Red Stripe too, which is closed source.


Copyright & License
-------------------

Sim Daltonism  
© 2005-2016 Michel Fortin  

Includes the color blindness simulation algorithm `color_blind_sim`.  
© 2000-2001 Matthew Wickline and the Human-Computer Interaction Resource Network

Sim Daltonism is available under the Apache 2.0 License.
See the *Apache License 2.0.txt* file for the complete terms.
Additional license terms apply to the color blindness simulation algorithm as 
follow:

	The color_blind_sims() JavaScript function in the is
	copyright (c) 2000-2001 by Matthew Wickline and the
	Human-Computer Interaction Resource Network ( http://hcirn.com/ ).

	The color_blind_sims() function is used with the permission of
	Matthew Wickline and HCIRN, and is freely available for non-commercial
	use. For commercial use, please contact the
	Human-Computer Interaction Resource Network ( http://hcirn.com/ ).
	(This notice constitutes permission for commercial use from Matthew
	Wickline, but you must also have permission from HCIRN.)
	Note that use of the color laboratory hosted at aware.hwg.org does
	not constitute commercial use of the color_blind_sims()
	function. However, use or packaging of that function (or a derivative
	body of code) in a for-profit piece or collection of software, or text,
	or any other for-profit work *shall* constitute commercial use.

	20151129 UPDATE
		HCIRN appears to no longer exist. This makes it impractical
		for users to obtain permission from HCIRN in order to use
		color_blind_sims() for commercial works. Instead:

		This work is licensed under a
		Creative Commons Attribution-ShareAlike 4.0 International License.
		http://creativecommons.org/licenses/by-sa/4.0/


### A note about that license

The copyright for the original color blindness simulation algorithm is shared 
by Matthew Wickline and the Human-Computer Interaction Resource Network. It 
seems the HCIRN is not reachable anymore, and it probably no longer exists.
Because of this, Matthew Wickline decided to to change the license to something 
he believed would reflect the original intent of the HCIRN. But it is possible 
that someone still owns the HCIRN copyright, which would make that license 
change legally contestable.

So I am relying solely on the older non-commercial clause for 
distributing this app.

If you distribute a derived work that does not include the color blindness
simulation algorithm derived from `color_blind_sim`, then you only have to
follow the terms of the Apache License 2.0.
