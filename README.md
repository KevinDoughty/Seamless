## Seamless

`Seamless.framework` for OSX and `libSeamless.a` for iOS enhance Core Animation with additive negative delta animation.
It adds simple animation smoothing or custom timing determined by blocks, 
to instances of `CABasicAnimation` with an extension to `CATransaction`,
or on instances of a `CAPropertyAnimation` subclass called `SeamlessAnimation`.
It is meant to be used where implicit animation is appropriate,
and is especially useful for the `NSAnimatablePropertyContainer` Protocol (`NSView` animation) which requires implicit animation.
Animations are declared with absolute values, 
but run relative to the underlying model value by animating from the old model value minus the new model value, 
to a destination value of zero.
This is the best technique for responding to rapid user events.


### CATransaction

#### `+(void)setSeamlessNegativeDelta:(BOOL)theSeamless`

Uses additive,
enables negative delta animation, 
uses previous values instead of presentation,
uses fillMode of kCAFillModeBackwards,
affects animation key naming behavior,

#### `+(void)setSeamlessSteps:(NSUInteger))theSteps`

Keyframes are used to emulate a custom timing function.
Without timing block this has no effect.
If not set, default is 100.

#### `+(void)setSeamlessTimingBlock:(SeamlessTimingBlock)theBlock;`

Set the block used for timing of animations in current transaction. 
Sole argument is a `double` between 0 and 1.
Return value is a `double` that can also be below 0 and above 1.
If not set, animations use a `CAMediaTimingFunction` with control points 0.5, 0.0, 0.5, 1.0 for simple smoothing.
Additive or negative delta behavior is not implied with this.

##### Discussion

Timing is emulated by replacing animations with instances of CAKeyframeAnimation behind the scenes.
Animated values must be one of transform, rect, size, point, float, or double.

##### Example

This gives a nice elastic wobble and is based on math from Matt Gallager's excellent [Animation Acceleration](http://www.cocoawithlove.com/2008/09/parametric-acceleration-curves-in-core.html).

```objc
[CATransaction setAnimationDuration:3.0];
[CATransaction setSeamlessNegativeDelta:YES];
[CATransaction setSeamlessTimingBlock:^ (double progress) {
	double omega = 20.0;
	double zeta = 0.5;
	double beta = sqrt(1.0 - zeta * zeta);
	return 1 - 1 / beta * expf(-zeta * omega * progress) * sinf(beta * omega * progress + atanf(beta / zeta));
}];
theFirstLayer.position = CGPointMake(100,100);
theSecondLayer.transform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
```


### CABasicAnimation

#### `-(void)setSeamlessNegativeDelta:(BOOL)theSeamless`

Overrides transaction value, with the same effect.

#### `-(void)setSeamlessSteps:(NSUInteger))theSteps`

Overrides transaction value, with the same effect.

#### `-(void)setSeamlessTimingBlock:(double (^)(double))theBlock;`

Overrides transaction value, with the same effect.


### SeamlessAnimation

Inherits from `CABasicAnimation`. 
Default values differ from CABasicAnimation:
additive = YES, 
fillMode = kCAFillModeBackwards, 
seamless = YES,
fromValue = old minus new, 
toValue = zero

#### `@property (copy) id oldValue;`

Optional. The layer's previous model value or what it is supposed to appear to be. 
You define the value absolutely but behind the scenes it is converted to a relative old minus new.

#### `@property (copy) id nuValue;`

Optional. The layer's current ("new") model value or what it is supposed to appear to be.
Behind the scenes, the actual animation destination is zero.


### `SeamlessTimingBlock`

`typedef double(^SeamlessTimingBlock)(double);`

## License

Released under the [BSD License](http://www.opensource.org/licenses/bsd-license).
Inslerpolate.c is adapted from WebKit source and released under a separate license.

## TODO:

Add a key naming behavior property and enum, which is needed if you want to retrieve animations for copying and applying them to newly inserted layers.

Because completely new animations are created and replace the passed in animations, arbitrary animation dictionaries and animation delegates are not respected. I should hold on to the original animation for this.

Documentation unfinished.

Need iOS examples.
