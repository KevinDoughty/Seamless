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

#### `+(void)setSeamlessTimingBlock:(SeamlessTimingBlock)theBlock;`

Set the block used for timing of animations in current transaction. 
Sole argument is a `double` between 0 and 1.
Return value is a `double` that can also be below 0 and above 1.

##### Discussion

Timing is emulated by replacing animations with instances of CAKeyframeAnimation behind the scenes.
Animated values must be one of transform, rect, size, point, float, or double.

##### Example

This gives a nice elastic wobble and is based on math from Matt Gallager's excellent [Animation Acceleration](http://www.cocoawithlove.com/2008/09/parametric-acceleration-curves-in-core.html).

```objc
[CATransaction setAnimationDuration:3.0];
[CATransaction setSeamlessTimingBlock:^ (double progress) {
	double omega = 20.0;
	double zeta = 0.5;
	double beta = sqrt(1.0 - zeta * zeta);
	return 1 - 1 / beta * expf(-zeta * omega * progress) * sinf(beta * omega * progress + atanf(beta / zeta));
}];
theFirstLayer.position = CGPointMake(100,100);
theSecondLayer.transform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
```


### SeamlessAnimation

Inherits from `CAPropertyAnimation`

##### `@property (copy) id oldValue;`

Optional. The layer's previous model value or what it is supposed to appear to be. 
You define the value absolutely but behind the scenes it is converted to a relative old minus new.

#### `@property (copy) id nuValue;`

Optional. The layer's current ("new") model value or what it is supposed to appear to be.
Behind the scenes, the actual animation destination is zero.

#### `@property (copy) SeamlessTimingBlock timingBlock;`

Optional. A block that specifies the timing of the animation. 
Sole argument is a `double` between 0 and 1.
Return value is a `double` that can also be below 0 and above 1.

##### Discussion

If there is a timing block for the current transaction, it operates on what this returns.
If not set, simple smoothing is achieved by using a "perfect" `[CAMediaTimingFunction functionWithControlPoints:0.5 :0.0 :0.5 :1.0f];`


### `SeamlessTimingBlock`

`typedef double(^SeamlessTimingBlock)(double);`

## License

Released under the [BSD License](http://www.opensource.org/licenses/bsd-license).
Inslerpolate.c is adapted from WebKit source and released under a separate license.

## TODO:

Resolve what happens if simple smoothing `SeamlessAnimation` is contained in a `CATransaction` with a timing block, 
or a `SeamlessAnimation` with a timing block is contained in a `CATransaction` with simple smoothing.
Currently can not combine simple smoothing with timing blocks.

Need iOS examples.