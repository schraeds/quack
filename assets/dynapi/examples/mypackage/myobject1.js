function MyObject0() {
	this.DynObject=DynObject;
	this.DynObject();
	this.value0 = 0;
}
dynapi.setPrototype('MyObject0','DynObject');

function MyObject1() {
	this.MyObject0=MyObject0;
	this.MyObject0();
	this.value1 = 1;
}
dynapi.setPrototype('MyObject1','MyObject0');

function main() {
	dynapi.debug.print('dynapi.library-myobject1.js main!');
}
if (!dynapi.loaded) main();