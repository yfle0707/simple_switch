# simple_switch

# Build p4 program
```
$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL --bindir=$SDE_INSTALL/bin P4_NAME=yle_simple_switch P4_PATH=$SDE/pkgsrc/p4-examples/p4_16_programs/simple_switch/simple_switch.p4 P4_VERSION=p4-16 P4_ARCHITECTURE=tna LDFLAGS="-L$SDE_INSTALL/lib" --enable-thrift
```

```
make clean
make 
make install 
```

# Build C program

```
cd run_rpc
make
```
