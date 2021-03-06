# dim.py
#
# Read the dimensions of the simulationp.
#
# Authors: S. Candelaresi (iomsn1@gmail.com), J. Oishi (joishi@amnh.org).
"""
Contains the classes and methods to read the simulation dimensions.
"""


def dim(*args, **kwargs):
    """
    Read the dim.dat file.

    call signature:

    dim(data_dir='data', proc=-1)

    Keyword arguments:

    *data_dir*:
      Directory where the data is stored.

    *proc*
      Processor to be read. If proc is -1, then read the 'global'
      dimensions. If proc is >=0, then read the dim.dat in the
      corresponding processor directory.
    """

    dim_tmp = Dim()
    dim_tmp.read(*args, **kwargs)
    return dim_tmp


class Dim(object):
    """
    Dim -- holds pencil code dimension data.
    """

    def __init__(self):
        """
        Fille members with default values.
        """

    def read(self, data_dir='data', proc=-1):
        """
        Read the dim.dat file.

        call signature:

        read(self, data_dir='data', proc=-1)

        Keyword arguments:

        *data_dir*:
          Directory where the data is stored.

        *proc*
          Processor to be read. If proc is -1, then read the 'global'
          dimensions. If proc is >=0, then read the dim.dat in the
          corresponding processor directory.
        """

        import os

        if proc < 0:
            file_name = os.path.join(data_dir, 'dim.dat')
        else:
            file_name = os.path.join(data_dir, 'proc{0}'.format(proc), 'dim.dat')

        try:
            file_name = os.path.expanduser(file_name)
            dim_file = open(file_name, "r")
        except IOError:
            print("File {0} could not be opened.".format(file_name))
            return -1
        else:
            lines = dim_file.readlines()
            dim_file.close()

        if len(lines[0].split()) == 6:
            self.mx, self.my, self.mz, self.mvar, self.maux, self.mglobal = \
            tuple(map(int, lines[0].split()))
        else:
            self.mx, self.my, self.mz, self.mvar, self.maux = \
            tuple(map(int, lines[0].split()))
            self.mglobal = 0

        self.precision = lines[1].strip("\n")
        self.nghostx, self.nghosty, self.nghostz = tuple(map(int, lines[2].split()))
        if proc < 0:
            # global
            self.nprocx, self.nprocy, self.nprocz, self.iprocz_slowest = \
            tuple(map(int, lines[3].split()))
            self.ipx = self.ipy = self.ipz = -1
        else:
            # local processor
            self.ipx, self.ipy, self.ipz = tuple(map(int, lines[3].split()))
            self.nprocx = self.nprocy = self.nprocz = self.iprocz_slowest = -1

        # Add derived quantities to the dim object.
        self.nx = self.mx - (2 * self.nghostx)
        self.ny = self.my - (2 * self.nghosty)
        self.nz = self.mz - (2 * self.nghostz)
        self.mw = self.mx * self.my * self.mz
        self.l1 = self.nghostx
        self.l2 = self.mx-self.nghostx-1
        self.m1 = self.nghosty
        self.m2 = self.my-self.nghosty-1
        self.n1 = self.nghostz
        self.n2 = self.mz-self.nghostz-1
        if self.ipx == self.ipy == self.ipz == -1:
            # global
            self.nxgrid = self.nx
            self.nygrid = self.ny
            self.nzgrid = self.nz
            self.mxgrid = self.nxgrid + (2 * self.nghostx)
            self.mygrid = self.nygrid + (2 * self.nghosty)
            self.mzgrid = self.nzgrid + (2 * self.nghostz)
        else:
            # local
            self.nxgrid = self.nygrid = self.nzgrid = 0
            self.mxgrid = self.mygrid = self.mzgrid = 0
